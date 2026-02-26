import Foundation
import Darwin

/// Loopback HTTP server for OAuth callback, using POSIX sockets (same approach as AppAuth).
/// Google Desktop app OAuth clients accept any http://127.0.0.1:PORT redirect without pre-registration.
final class OAuthCallbackServer {

    func waitForCode(onReady: (String) -> Void) async throws -> (code: String, redirectURI: String) {
        let (serverFD, port) = try bindAndListen()
        let redirectURI = "http://127.0.0.1:\(port)"
        onReady(redirectURI)

        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let code = try self.acceptAndReadCode(serverFD: serverFD)
                    cont.resume(returning: (code, redirectURI))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func bindAndListen() throws -> (fd: Int32, port: UInt16) {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw AuthError.oauthError("socket() errno \(errno)") }

        var one: Int32 = 1
        Darwin.setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = 0                               // OS picks a free port
        addr.sin_addr   = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)

        guard withUnsafePointer(to: &addr, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }) == 0 else {
            Darwin.close(fd)
            throw AuthError.oauthError("bind() errno \(errno)")
        }

        guard Darwin.listen(fd, 1) == 0 else {
            Darwin.close(fd)
            throw AuthError.oauthError("listen() errno \(errno)")
        }

        // Read back the OS-assigned port
        var assigned = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(fd, $0, &len)
            }
        }
        return (fd, UInt16(bigEndian: assigned.sin_port))
    }

    private func acceptAndReadCode(serverFD: Int32) throws -> String {
        defer { Darwin.close(serverFD) }

        var clientAddr = sockaddr_in()
        var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let clientFD = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.accept(serverFD, $0, &clientLen)
            }
        }
        guard clientFD >= 0 else { throw AuthError.oauthError("accept() errno \(errno)") }
        defer { Darwin.close(clientFD) }

        var buffer = [UInt8](repeating: 0, count: 8192)
        let n = Darwin.read(clientFD, &buffer, buffer.count - 1)

        // Send response immediately so the browser doesn't spin
        let body = "<h1>Signed in!</h1><p>You can close this tab.</p>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        Darwin.write(clientFD, response, response.utf8.count)

        guard n > 0 else { throw AuthError.oauthError("Empty HTTP request") }

        let request = String(bytes: buffer.prefix(n), encoding: .utf8) ?? ""
        return try parseCode(from: request)
    }

    private func parseCode(from httpRequest: String) throws -> String {
        // First line: "GET /?code=xxx&state=yyy HTTP/1.1"
        guard let line = httpRequest.split(separator: "\r\n").first,
              line.hasPrefix("GET "),
              let qMark = line.firstIndex(of: "?") else {
            throw AuthError.oauthError("Unexpected callback format")
        }

        let query = String(line[line.index(after: qMark)...].prefix(while: { $0 != " " }))
        let items = URLComponents(string: "http://x?\(query)")?.queryItems ?? []

        if let err = items.first(where: { $0.name == "error" })?.value {
            throw AuthError.oauthError(err)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw AuthError.oauthError("No code in callback")
        }
        return code
    }
}

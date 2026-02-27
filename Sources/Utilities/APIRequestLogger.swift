import Foundation

struct APIRequestLogEntry: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let operation: String
    let method: String
    let path: String
    let statusCode: Int
    let errorMessage: String?

    init(timestamp: Date, operation: String, method: String, path: String, statusCode: Int, errorMessage: String?) {
        self.id = UUID().uuidString
        self.timestamp = timestamp
        self.operation = operation
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.errorMessage = errorMessage
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, operation, method, path, statusCode, errorMessage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        operation = try c.decode(String.self, forKey: .operation)
        method = try c.decode(String.self, forKey: .method)
        path = try c.decode(String.self, forKey: .path)
        statusCode = try c.decode(Int.self, forKey: .statusCode)
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(operation, forKey: .operation)
        try c.encode(method, forKey: .method)
        try c.encode(path, forKey: .path)
        try c.encode(statusCode, forKey: .statusCode)
        try c.encodeIfPresent(errorMessage, forKey: .errorMessage)
    }
}

final class APIRequestLogger {
    static let shared = APIRequestLogger()
    static let maxEntries = 200

    private let queue = DispatchQueue(label: "APIRequestLogger")
    private(set) var entries: [APIRequestLogEntry] = []
    private var logFileURL: URL?

    init() {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("BCalendar", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            logFileURL = dir.appendingPathComponent("api-log.json")
            load()
        }
    }

    func log(operation: String, method: String, path: String, statusCode: Int, errorMessage: String? = nil) {
        queue.async {
            let entry = APIRequestLogEntry(
                timestamp: Date(),
                operation: operation,
                method: method,
                path: path,
                statusCode: statusCode,
                errorMessage: errorMessage
            )
            self.entries.insert(entry, at: 0)
            if self.entries.count > Self.maxEntries {
                self.entries.removeLast()
            }
            self.save()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .apiRequestLogChanged, object: nil)
            }
        }
    }

    func clear() {
        queue.async {
            self.entries.removeAll()
            self.save()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .apiRequestLogChanged, object: nil)
            }
        }
    }

    func getEntries() -> [APIRequestLogEntry] {
        queue.sync { entries }
    }

    private func load() {
        guard let url = logFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([APIRequestLogEntry].self, from: data) else { return }
        queue.sync { self.entries = decoded }
    }

    private func save() {
        guard let url = logFileURL,
              let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url)
    }
}

extension Notification.Name {
    static let apiRequestLogChanged = Notification.Name("apiRequestLogChanged")
}

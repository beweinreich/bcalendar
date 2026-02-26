# BCalendar

BCalendar is a macOS application that allows you to manage your calendar. It is a work in progress and is not yet ready for use.

It's supposed to be the same as Apple calendar, but with fewer bugs. But, also— I don't have time.

## Google Calendar Setup

1. Create a **Desktop app** OAuth client in [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.
2. Add `http://127.0.0.1:8080` to **Authorized redirect URIs**.
3. Copy the Client ID and Client Secret into `Resources/Secrets.plist` (see `Secrets.plist.example` if present).

## Build

```
killall BCalendar 2>/dev/null || true
xcodegen generate
xcodebuild -project BCalendar.xcodeproj -scheme BCalendar -derivedDataPath .build -destination 'platform=macOS' build

open .build/Build/Products/Debug/BCalendar.app
```

# BCalendar

BCalendar is a macOS application that allows you to manage your calendar. It is a work in progress and is not yet ready for use.

It's supposed to be the same as Apple calendar, but with fewer bugs. But, also— I don't have time.

## Build

```
cd /Users/bw/Webstuff/bcalendar
xcodegen generate
xcodebuild -project BCalendar.xcodeproj -scheme BCalendar -derivedDataPath .build -destination 'platform=macOS' build

open .build/Build/Products/Debug/BCalendar.app
```

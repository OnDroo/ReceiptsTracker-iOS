# Receipts (iOS)

Native **SwiftUI** iOS port of [ReceiptsTracker](https://github.com/OnDroo/ReceiptsTracker) (Android) — scan, organize, and search receipts using the Google Gemini API.

## Tech Stack
- **UI**: SwiftUI (iOS 17+)
- **Persistence**: SwiftData (replaces Android Room)
- **Settings / Secrets**: Keychain (API key) + `@AppStorage` / `UserDefaults` (currency, selected model)
- **Networking**: `URLSession` + `Codable` (Google Gemini REST API)
- **Document Scanning**: VisionKit (`VNDocumentCameraViewController`)

## Opening in Xcode (macOS)
This repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the `.xcodeproj` can be generated cleanly on macOS:

```bash
brew install xcodegen
xcodegen generate
open ReceiptsTracker.xcodeproj
```

## Porting Reference
See [PORTING_GUIDE.md](PORTING_GUIDE.md) for the full 1:1 mapping of Android models, Room schema, Gemini prompts, settings, and screens to SwiftUI.
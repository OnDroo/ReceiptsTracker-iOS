# Receipts (iOS)

Native **SwiftUI** iOS port of [ReceiptsTracker](https://github.com/OnDroo/ReceiptsTracker) (Android) — scan, organize, and search receipts using the Google Gemini API.

## Native iOS & iPhone Duo Highlights
- **iOS 26 Liquid Glass**: Uses native `GlassEffectContainer`, `.glassEffect(...)`, and `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` on iOS 26+ with graceful frosted material fallbacks on iOS 17–25.
- **iPhone Duo & iPad Adaptive**:
  - Zero `UIScreen.main`, hardcoded screen widths, orientation locks, or `.pad` idiom checks.
  - Adapts dynamically via `@Environment(\.horizontalSizeClass)` between the 5.4" outer display (`.compact`) and the 7.6" unfolded inner display (`.regular`):
    - Adaptive `TabView` (`.tabViewStyle(.sidebarAdaptable)` on iOS 18+)
    - `NavigationSplitView` for side-by-side Receipts list & detail with live fold-state preservation
    - 2-column Dashboard charts grid and side-by-side Items + Receipt Scan detail layout
  - All toolbar actions provide both a title and an SF Symbol (`Label`) for vertical edge-bar compatibility.
- **Swift Charts**: Native area/line spending trend charts and `SectorMark` category donut charts.

## Tech Stack
- **UI**: SwiftUI (iOS 17+, Liquid Glass on iOS 26+) + Swift Charts
- **Persistence**: SwiftData (replaces Android Room)
- **Settings / Secrets**: Keychain (API key) + `UserDefaults` (currency, selected model)
- **Networking**: `URLSession` + `Codable` (Google Gemini REST API)
- **Document Scanning**: VisionKit (`VNDocumentCameraViewController`) + `PhotosPicker`

## Opening in Xcode (macOS)
This repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the `.xcodeproj` can be generated cleanly on macOS:

```bash
brew install xcodegen
xcodegen generate
open ReceiptsTracker.xcodeproj
```

## CI Build & Tests
GitHub Actions workflow [`.github/workflows/ios-ci.yml`](.github/workflows/ios-ci.yml) runs on `macos-latest` to generate the Xcode project, build the app, and run all `ReceiptsTrackerTests` on an iOS Simulator.

## Porting Reference
See [PORTING_GUIDE.md](PORTING_GUIDE.md) for the full 1:1 mapping of Android models, Room schema, Gemini prompts, settings, and screens to SwiftUI.
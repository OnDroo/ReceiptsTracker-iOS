# Product Requirements Document (PRD) — Receipts (iOS)

## 1. Overview
**Receipts** is a native iOS / iPadOS SwiftUI application (ported from the Android [ReceiptsTracker](https://github.com/OnDroo/ReceiptsTracker) app) for scanning, organizing, searching, and analyzing paper or digital receipts using the Google Gemini API.

## 2. Target Platforms & Technical Stack
- **Platforms**: iPhone, iPhone Duo (adaptive compact/regular fold states), and iPad (iOS 17.0+, with native iOS 26 Liquid Glass styling and material fallbacks for iOS 17–25).
- **UI**: SwiftUI (`TabView`, `NavigationStack`, `NavigationSplitView`, `.sheet`, Swift Charts).
- **State Management**: Observation framework (`@Observable`, `@State`, `@Bindable`, `@Environment`) — zero legacy `ObservableObject` / `@Published`.
- **Persistence**: SwiftData (`@Model` entities `Receipt`, `ReceiptItem`, `Category`), `UserDefaults` for user preferences (currency, AI model), and iOS Keychain for the Gemini API key.
- **Networking**: `URLSession` + `async`/`await` + `Codable` against the Google Gemini REST API.
- **System Integration**: `AppIntents` & `AppShortcutsProvider` for Apple Shortcuts and Siri.
- **Scanning**: VisionKit (`VNDocumentCameraViewController`) + `PhotosPicker`.

## 3. Core Features

### 3.1 Dashboard
- Displays total spending and receipt count for the selected period (`This Week`, `This Month`, `This Year`, `All Time`).
- Automatically converts multi-currency receipts (EUR, USD, CZK, GBP, PLN) into the user's preferred currency.
- Visualizes spending trends (area/line Swift Chart) and category breakdown (`SectorMark` donut chart).
- Lists recent transactions with one-tap navigation to Receipt Details.
- Provides top-right access to Settings via a modal `.sheet`.

### 3.2 Receipts List, Search & Filtering
- Chronologically grouped receipt list by month (`MMMM yyyy`).
- Real-time full-text search across store names and individual purchased line items.
- Category filter pills (`All`, plus seeded categories with SF Symbols and color tints).
- Swipe-to-delete receipts (also removes stored JPEG scans from disk).
- Adaptive layout: `NavigationStack` on compact width; 2-column `NavigationSplitView` on regular width (iPad / unfolded Duo) preserving the selected receipt across size-class transitions.

### 3.3 Receipt Details & Editing
- Displays merchant header, category badge, total amount, payment method, and transaction ID.
- Compact layout switches between `Items` and `Raw Image` via a segmented picker; wide containers (`width >= 660pt`) show Purchased Items and Receipt Scan side by side.
- Full-screen zoomable receipt image viewer, Share Sheet export, and Save to Photos.
- Edit Receipt `.sheet` supporting edits to store name, date, currency, category, payment method, transaction ID, and line items (add/edit/delete) with automatic total recalculation.

### 3.4 Receipt Scanning & AI Extraction
- Dedicated `Scan` tab supporting both camera document scanning (VisionKit) and importing existing images (`PhotosPicker`).
- Compresses and stores the scan locally, sends it to the selected Gemini model with structured JSON extraction prompt, persists the parsed receipt & items to SwiftData, and opens the newly created Receipt Details.
- Clear error & retry sheet when the API key is missing/invalid or network analysis fails, allowing inline API key entry and immediate retry.

### 3.5 Settings
- Preferred currency selector (`EUR`, `USD`, `CZK`, `GBP`, `PLN`) immediately recalculating Dashboard totals and charts.
- Gemini API key stored securely in the iOS Keychain with `Saved` status indicator and Show/Hide toggle.
- AI model selector with live refresh of available models from the Gemini API.

### 3.6 App Intents (Shortcuts & Siri)
- **`GetMonthlySpendingIntent`** (*"Show monthly spending in Receipts"*): Runs in the background (`openAppWhenRun = false`), queries SwiftData for the current month's receipts, converts totals into the user's preferred currency, and speaks/returns a formatted dialog summary (handling empty state, singular `"1 receipt"`, and plural counts).
- **`ScanReceiptIntent`** (*"Scan a receipt in Receipts"*): Opens the app directly to the `Scan` tab (`openAppWhenRun = true`) for instant capture from Shortcuts, Siri, or the Action Button.

---

## 4. Testable Acceptance Criteria

| ID | Area | Acceptance Criterion |
|---|---|---|
| **AC-01** | Build | Project generates cleanly via `xcodegen generate` and compiles without errors for both iOS Simulator and physical arm64 iOS (`Release` archive). |
| **AC-02** | Persistence | Receipts, line items, and category assignments saved in SwiftData persist across full app termination and relaunch. |
| **AC-03** | Settings Persistence | Selected currency and AI model persist in `UserDefaults`; Gemini API key persists in the iOS Keychain and is never committed to git or logged. |
| **AC-04** | Multi-Currency Math | Dashboard totals, charts, and monthly spending intent convert receipts in EUR/USD/CZK/GBP/PLN into the user's preferred currency accurately. |
| **AC-05** | Search & Filtering | Typing an item name (e.g., `"Milk"`) or store name filters the Receipts list accurately; combining search with a category chip intersects both filters; clearing search restores all rows. |
| **AC-06** | Safe Deletion | Swiping to delete a receipt from a filtered/searched list deletes the exact selected receipt ID (never a wrong index) and removes its local image file. |
| **AC-07** | Edge Cases | Empty database shows helpful empty states (`ContentUnavailableView`) without crashing; division by zero in category percentages is guarded; invalid/missing API key shows an actionable retry sheet instead of a silent failure. |
| **AC-08** | App Intents | Both **Get Monthly Spending** and **Scan Receipt** appear in the Apple Shortcuts app (`Zkratky`) under **Receipts**; running **Get Monthly Spending** with zero receipts returns a friendly empty-state sentence, and with receipts returns the converted monthly total and count; running **Scan Receipt** opens the app directly on the `Scan` tab. |
| **AC-09** | Adaptive UI | App renders cleanly in dark and light mode across compact iPhone (portrait) and wide iPad / unfolded Duo (landscape) without clipped text, squished columns, or misaligned headers. |
| **AC-10** | Automated Tests | Unit test suite (`ReceiptsTrackerTests`) covers currency/date utilities, SwiftData CRUD & persistence, Gemini JSON decoding & error handling, ViewModels, and App Intents — all passing on CI. |

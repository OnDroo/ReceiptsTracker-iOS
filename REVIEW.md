# Code Review & Verification Log (`REVIEW.md`)

This document reviews the architecture decisions made while building **Receipts (iOS)** with an AI coding agent, issues caught during review (checked against the AP9PT `agent-gotchas.md` checklist), and how each requirement was verified.

---

## 1. Key Architectural Decisions Made by the Agent

| Area | Decision | Rationale & Review Evaluation |
|---|---|---|
| **State Ownership** | Single `@Observable final class AppContainer` instantiated via `@State` in `ReceiptsTrackerApp` and injected with `.environment(container)`. All 5 ViewModels and `SettingsStore` also use `@Observable`. | Follows iOS 17+ Observation best practices (zero legacy `ObservableObject` / `@Published`). Prevents accidental state recreation on view redraws and avoids prop-drilling dependencies through intermediate views. |
| **SwiftData + Snapshot DTOs** | SwiftData `@Model` classes (`Receipt`, `ReceiptItem`, `Category`) are mapped to immutable `Sendable` structs (`ReceiptSnapshot`, `ReceiptItemSnapshot`, `CategorySnapshot`) at the repository boundary (`SwiftDataReceiptRepository`). | Keeps UI ViewModels decoupled from `ModelContext` threading rules, makes unit testing deterministic with in-memory `ModelContainer`s, and prevents crashes if a model is deleted while referenced in UI state. |
| **Security & Preferences Split** | Gemini API key stored in iOS Keychain (`KeychainHelper`); currency and selected AI model stored in `UserDefaults` (`SettingsStore`). | Keeps sensitive credentials out of plain `UserDefaults` while allowing `AppIntents` and settings views to read non-sensitive preferences cleanly. |
| **Networking** | Native `URLSession` + `async`/`await` + `Codable` (`GeminiService`) with explicit `GeminiServiceError` cases (missing key, HTTP 401/403, malformed JSON). | Zero third-party dependencies (keeps Release `.ipa` compact at ~1.35 MB including icons) and maps errors to an actionable retry sheet. |
| **Adaptive Layout** | Standard SwiftUI `TabView` (3 tabs: `Dashboard`, `Receipts`, `Scan`), `NavigationSplitView` on `.regular` width, and `GeometryReader` width checks (`>= 660pt`) inside `ReceiptDetailView`. | Avoids hardcoded `UIScreen.main` dimensions or `.pad` idiom checks so the app adapts smoothly across iPhone, iPad, and unfolded iPhone Duo. |
| **App Intents Bridge** | `GetMonthlySpendingIntent` reuses `AppContainer.active` when running and falls back to `PersistenceController.makeModelContainer(inMemory: false)` when invoked headless from Shortcuts. `ScanReceiptIntent` uses `IntentNavigationBridge` (`pendingTab` + `NotificationCenter`) so both cold and warm launches land on the `Scan` tab. | Ensures Shortcuts work reliably whether the app is terminated, backgrounded, or foregrounded. |

---

## 2. Issues Caught & Fixed During Review

1. **Missing `AppIntent` requirement**:
   - *Found*: Initial port from Android had SwiftUI, `@Observable`, SwiftData, and Gemini API, but lacked any `AppIntent` / `AppShortcutsProvider`.
   - *Fix*: Added `GetMonthlySpendingIntent`, `ScanReceiptIntent`, and `ReceiptsShortcuts` in `ReceiptsTracker/App/ReceiptsAppIntents.swift`, wired `AppNavigationView` to handle tab navigation requests, and added unit tests in `AppIntentsTests.swift`.
2. **3-Column Squishing on Wide Split View (`ReceiptDetailView`)**:
   - *Found*: Checking `horizontalSizeClass == .regular` inside `NavigationSplitView`'s detail pane forced a 2-column detail layout even when the detail pane was narrow, squishing prices and category badges onto multiple lines.
   - *Fix*: Switched `ReceiptDetailView` to inspect available container width via `GeometryReader` (`proxy.size.width >= 660`) and enforced `.lineLimit(1)` + `.layoutPriority(1)` on price and pill labels.
3. **Oversized Empty Sidebar & Uneven Card Heights on iPad/Wide Dashboard**:
   - *Found*: Using `.tabViewStyle(.sidebarAdaptable)` rendered a tall empty left sidebar column for just 3 tabs, and `Spending Trends` / `Spending by Category` cards had mismatched heights.
   - *Fix*: Removed `.tabViewStyle(.sidebarAdaptable)` so iPad uses Apple's compact floating Liquid Glass top tab pill (and iPhone uses the floating bottom pill), and aligned both Dashboard chart cards to equal height with `.fixedSize(horizontal: false, vertical: true)` + `maxHeight: .infinity`.
4. **Blank-Looking API Key Row in Settings**:
   - *Found*: Placing `Label`, `SecureField`, and a bordered `Show` button in one `Form` `HStack` collapsed the label and left the row appearing empty in screenshots.
   - *Fix*: Redesigned as a two-line row with explicit `Gemini API Key` title, green `Saved` badge, `.buttonStyle(.borderless)` Show/Hide toggle, and a full-width monospaced field.
5. **Inconsistent Vertical Header Alignment Across Tabs**:
   - *Found*: `Dashboard` hid the empty 44pt navigation bar to put `Dashboard` and Settings on one row, whereas `Receipts` and `Scan Receipt` kept the empty 44pt system bar, pushing their titles noticeably lower.
   - *Fix*: Hid the empty navigation bar on compact `ReceiptListView` and tabbed `ScanReceiptView` and rendered inline `.largeTitle.bold()` headers at the exact same `12pt` top offset, while keeping the system nav bar on wide `NavigationSplitView` so the sidebar toggle remains accessible.
6. **Missing App Icon Assets**:
   - *Found*: `AppIcon.appiconset` had empty placeholder entries.
   - *Fix*: Converted the Android rainbow-receipt icon into 1024×1024 iOS Light, defringed Dark, and Tinted PNG assets and verified `Assets.car` inside the release `.ipa`.
7. **Mixed Responsibilities Inside `Data/Repositories/`**:
   - *Found*: Carryover from Android's `*Repository` naming left `GeminiService` (remote HTTP API client) and `SettingsStore` (preferences) inside `Data/Repositories/` alongside the SwiftData repository, while stateful disk I/O (`FileStorageHelper`) lived in `Utils/`.
   - *Fix*: Separated `Data/` cleanly by role — `Data/Services/GeminiService.swift` (remote API), `Data/Persistence/` (`PersistenceController`, `KeychainHelper`, `SettingsStore`, `FileStorageHelper`), and `Data/Repositories/` (strictly `ReceiptRepositoryProtocol` + `SwiftDataReceiptRepository`) — leaving `Utils/` for pure stateless formatting/mapping helpers.

---

## 3. `agent-gotchas.md` Checklist Audit

- **Section 0 (Spec vs. Implementation)**: Verified every acceptance criterion in [PRD.md](PRD.md) against concrete source files and automated tests.
- **Section 1 (Edge Cases)**:
  - Empty receipts list & empty current month handled with `ContentUnavailableView` and empty-state Shortcuts dialog.
  - Zero-total division guarded in `DashboardViewModel` category breakdown (`totalAmount > 0`).
  - Missing/invalid Gemini API key surfaces `ErrorRetrySheet` with inline key entry instead of crashing or failing silently.
  - Duplicate store names or items are safe because all SwiftData entities and snapshot structs use unique `id: String` (`UUID`).
- **Section 2 (`@State` & `@Binding`)**: Single source of truth for `AppContainer` (`@State private var container` in `ReceiptsTrackerApp`); all view-local `@State` properties are `private`; child editors receive explicit bindings or callbacks.
- **Section 3 (`@Observable` & `.environment`)**: Verified via codebase grep — zero `ObservableObject` or `@Published` declarations. Every `#Preview` injects `.environment(AppContainer.preview)` so previews never crash at runtime.
- **Section 4 (`List`, `ForEach`, Deletion)**: `ForEach` iterates over `Identifiable` items; `.onDelete` is placed on `ForEach` (not `List`) and deletes by `section.items[idx].id` (receipt ID lookup in SwiftData), so deleting from a searched or category-filtered list always removes the exact intended receipt.
- **Section 5 (Sheets & `dismiss`)**: Modals (`SettingsView`, `EditReceiptView`, `ErrorRetrySheet`) use explicit `onDismiss` / `@Environment(\.dismiss)` with `dismiss()` inside the sheet content.
- **Section 6 (Layout & Modifiers)**: Verified across portrait iPhone (`iPhone 17 Pro`) and landscape wide (`iPad mini`) via automated simulator screenshots; no hardcoded screen sizes or `UIScreen.main`.

---

## 4. Verification Summary

- **Unit Tests (`iOS Build & Test` GitHub Actions on `macos-latest`)**:
  - `CurrencyAndDateUtilsTests`: Currency conversion, formatting, Gemini date parsing.
  - `SwiftDataRepositoryTests`: Save, upsert, update item diffing, delete, and category seeding in SwiftData.
  - `GeminiServiceTests`: JSON response parsing, markdown-fenced responses, missing key & HTTP error handling.
  - `ViewModelsTests`: Dashboard time filtering, currency conversion, `"Others"` category grouping, receipt search & filtering.
  - `AppIntentsTests`: Empty state, singular/plural phrasing, current-month filtering, currency conversion, `ScanReceiptIntent` tab routing, and `ReceiptsShortcuts` registration.
- **UI & Visual Verification (`iOS Simulator Screenshots` workflow)**:
  - Automated `XCUITest` (`ScreenshotUITests`) navigates every screen (`Dashboard`, `Receipt Details`, `Raw Image`, `Edit Receipt`, `Receipts List`, `Scan Receipt`, `Settings`) on both compact iPhone and landscape iPad mini simulators.
- **Real-Device Packaging (`iOS Release (Unsigned IPA)` workflow)**:
  - Verified `Release` arm64 archive builds cleanly via `xcodebuild archive` (`generic/platform=iOS`), producing a valid arm64 Mach-O executable and compiled `Assets.car` inside `Receipts-1.0.0.ipa` for sideloading on a physical iPhone via Impactor / SideStore.

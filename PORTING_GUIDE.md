# Android → iOS (SwiftUI) Porting Guide

Source Android repository: `../ReceiptsTracker` (`https://github.com/OnDroo/ReceiptsTracker`)

## 1. Tech Stack Mapping

| Layer | Android (`ReceiptsTracker`) | iOS (`ReceiptsTracker-iOS`) |
| :--- | :--- | :--- |
| UI Framework | Jetpack Compose (Material 3) | SwiftUI (iOS 17+) |
| Architecture | MVVM (`ViewModel` + `StateFlow`) | MVVM (`@Observable` + `async`/`await`) |
| Navigation | Navigation Compose (`Screen`) | `TabView` / `NavigationStack` + `NavigationPath` |
| Database | Room (`AppDatabase`, `ReceiptDao`) | SwiftData (`@Model`, `ModelContainer`) |
| Preferences | DataStore (`user_settings`) | Keychain (`api_key`) + `@AppStorage` (`currency`, `gemini_model`) |
| Networking | Ktor Client + `kotlinx.serialization` | `URLSession` + `Codable` |
| Image Loading | Coil (`coil-compose`) | Local `FileManager` Documents dir + `UIImage` / `Image` |
| Document Scanner | ML Kit Document Scanner | VisionKit `VNDocumentCameraViewController` + `PhotosPicker` |

## 2. Data Models & Persistence

Mirror the Android entities from `app/src/main/java/link/ondrov/receipts/data/model/`:

- **`Receipt`**: `id: String`, `storeName: String`, `totalAmount: Double`, `dateTimestamp: Date`, `currency: String`, `category: Category?`, `imageFileName: String`, `paymentMethod: String?`, `transactionId: String?`, `items: [ReceiptItem]` (cascade delete).
- **`ReceiptItem`**: `id: String`, `name: String`, `quantity: Double`, `unit: String?`, `price: Double`, relationship back to `Receipt`.
- **`Category`**: `id: String`, `name: String`, `iconId: String`.

### Default Seed Categories (from `AppDatabase.kt`)
Seed on first launch if empty:
1. `cat_groceries` — `Groceries` (`shopping_cart`)
2. `cat_dining` — `Dining Out` (`restaurant`)
3. `cat_transport` — `Transport` (`bus`)
4. `cat_tech` — `Electronics` (`tech`)
5. `cat_health` — `Health` (`health`)
6. `cat_utilities` — `Bills & Utils` (`utilities`)
7. `cat_shopping` — `Shopping` (`gift`)

## 3. Settings & Defaults (from `SettingsRepository.kt`)
- `api_key`: `""` (store in iOS Keychain)
- `currency`: `"EUR"`
- `gemini_model`: `"gemini-4-hydrogen"`

## 4. Gemini API Integration (from `GeminiRepository.kt`)
- **List Models**: `GET https://generativelanguage.googleapis.com/v1beta/models?key={apiKey}`
  - Filter: `supportedGenerationMethods` contains `"generateContent"`, name contains `"gemini"`, and name contains `"hydrogen"`, `"flash"`, or `"pro"`.
  - Strip `"models/"` prefix; sort with `"hydrogen"` then `"flash"` models first, then descending alphabetically.
- **Analyze Receipt**: `POST https://generativelanguage.googleapis.com/v1beta/models/{modelName}:generateContent?key={apiKey}`
  - Send prompt + base64 JPEG (quality ~0.8) with `generationConfig.responseMimeType = "application/json"` and strict `responseSchema` (`storeName`, `totalAmount`, `currency`, `date` as `YYYY-MM-DD HH:mm:ss`, `categoryName` enum, `items[]`, `metadata`).
  - Save receipt image locally in the app's Documents directory (`{receiptId}.jpg`).

## 5. Screen & Feature Checklist

- [x] **Theme & Utils** (`UI/Theme/`, `Utils/`): Semantic Apple HIG theme, iOS 26 Liquid Glass modifiers (`GlassModifiers.swift`) with iOS 17–25 fallback, currency conversion/formatting, localized date & Gemini date formatting, SF Symbols icon registry, local Documents file storage helper.
- [x] **Data Layer** (`Data/`): SwiftData models (`Receipt`, `ReceiptItem`, `Category`), idempotent default category seeding, `ReceiptRepositoryProtocol` & `SwiftDataReceiptRepository`, Keychain + `UserDefaults` `SettingsStore`, `URLSession`-based `GeminiService`.
- [x] **Navigation** (`UI/Navigation/`): Adaptive `TabView` (`.sidebarAdaptable` on iOS 18+), `NavigationSplitView` for unfolded iPhone Duo / iPad (`.regular` width) collapsing seamlessly to `NavigationStack` on `.compact` width with live state preservation.
- [x] **Dashboard Screen**: Time filters (`This Week`, `This Month`, `This Year`, `All Time`), summary stat cards, Swift Charts spending trends & `SectorMark` category donut, recent transactions, adaptive 2-column grid for iPhone Duo, Liquid Glass floating Scan action.
- [x] **Receipt List & Search Screen**: Native `.searchable` full-text search across store names and line items (with matched item bullets), Liquid Glass category filter chips, month grouping, swipe-to-delete, split-view selection on `.regular` width.
- [x] **Scan Receipt Screen**: VisionKit `VNDocumentCameraViewController` + `PhotosPicker` import -> Gemini analysis -> Liquid Glass analyzing overlay -> `ErrorRetrySheet` (inline API key fix or model switcher) -> navigate directly to receipt detail.
- [x] **Receipt Detail Screen**: Adaptive side-by-side items + raw image layout on unfolded iPhone Duo (`.regular` width) and segmented `Items` / `Raw Image` picker on `.compact`, pinch-to-zoom full-screen viewer, Save to Photos, Share, Edit, and Delete confirmation.
- [x] **Edit Receipt Screen**: Native iOS `Form` editing store, date/time, category, currency, metadata, and line items with auto-calculated total.
- [x] **Settings Screen**: Native `Form` for preferred currency, Keychain-backed Gemini API key with debounced save, and dynamic Gemini model picker.
- [x] **CI & Unit Tests**: XCTest unit tests (`ReceiptsTrackerTests/`) and GitHub Actions `macos-latest` build & test workflow (`.github/workflows/ios-ci.yml`).
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
- `gemini_model`: `"gemini-2.5-flash"`

## 4. Gemini API Integration (from `GeminiRepository.kt`)
- **List Models**: `GET https://generativelanguage.googleapis.com/v1beta/models?key={apiKey}`
  - Filter: `supportedGenerationMethods` contains `"generateContent"`, name contains `"gemini"`, and name contains `"flash"` or `"pro"`.
  - Strip `"models/"` prefix; sort with `"flash"` models first, then descending alphabetically.
- **Analyze Receipt**: `POST https://generativelanguage.googleapis.com/v1beta/models/{modelName}:generateContent?key={apiKey}`
  - Send prompt + base64 JPEG (quality ~0.8) with `generationConfig.responseMimeType = "application/json"` and strict `responseSchema` (`storeName`, `totalAmount`, `currency`, `date` as `YYYY-MM-DD HH:mm:ss`, `categoryName` enum, `items[]`, `metadata`).
  - Save receipt image locally in the app's Documents directory (`{receiptId}.jpg`).

## 5. Screen & Feature Checklist

- [ ] **Theme & Utils** (`UI/Theme/`, `Utils/`): Colors, typography, currency formatting, date formatting, icon registry (SF Symbols mapping), local file storage helper.
- [ ] **Data Layer** (`Data/`): SwiftData models, default category seeding, repository protocol & SwiftData implementation, Keychain + Settings store, Gemini API service.
- [ ] **Navigation** (`UI/Navigation/`): `Dashboard`, `ReceiptList`, `Scan`, `ReceiptDetail(id)`, `EditReceipt(id)`, `Settings`.
- [ ] **Dashboard Screen**: Spending summary/report, recent receipts, quick scan action.
- [ ] **Receipt List & Search Screen**: Full-text search across store, items, categories, filtering.
- [ ] **Scan Receipt Screen**: VisionKit document camera + photo picker -> Gemini analysis -> loading/error retry -> navigate to receipt details.
- [ ] **Receipt Detail Screen**: Receipt image preview, itemized breakdown, metadata, delete & edit actions.
- [ ] **Edit Receipt Screen**: Edit store, total, date, currency, category, and line items.
- [ ] **Settings Screen**: Gemini API key input, fetch & select available Gemini model, preferred currency picker.
# Receipts

**Receipts** is a native iOS application designed to help you manage and organize your receipts with ease — the SwiftUI port of [ReceiptsTracker](https://github.com/OnDroo/ReceiptsTracker). Leveraging the power of the Google Gemini API, it automatically extracts store details, line items, totals, and categories so you can track spending and find any receipt by its content.

## Features

* **Receipt Management**: Store and organize all your receipts in one place. Scan paper receipts with the VisionKit document scanner or import existing photos, and the app will handle the rest.
* **Spending Dashboard**: View spending trends and category breakdowns with native Swift Charts across weekly, monthly, yearly, and all-time ranges.
* **Search & Filtering**: Search receipts by store name or purchased items and filter by category.
* **Customizable Settings**:
  * Set your preferred currency (EUR, USD, CZK, etc.) with automatic conversion.
  * Choose your preferred AI Model (e.g., `gemini-4-hydrogen`) and refresh available models from Gemini.
  * API key is stored securely in the iOS Keychain.
* **Shortcuts & Siri (`AppIntents`)**: Check your monthly spending summary or jump straight into the receipt scanner from Apple Shortcuts, Siri, or the Action Button.
* **Native iOS Design**: Built with SwiftUI, iOS 26 Liquid Glass, and adaptive layouts for iPhone, iPhone Duo, and iPad.

## Screenshots

| Dashboard | Search | Receipt Details | Scanner |
|:---:|:---:|:---:|:---:|
| <img src="screenshots/dashboard.png" width="200" alt="Dashboard Screenshot" /> | <img src="screenshots/search.png" width="200" alt="Search Screenshot" /> | <img src="screenshots/details.png" width="200" alt="Receipt Details Screenshot" /> | <img src="screenshots/scanner.png" width="200" alt="Scanner Screenshot" /> |

## Setup & Configuration

This application requires a Google Gemini API Key to scan and analyze receipts.

### 1. Get a Free API Key
1. Go to [Google AI Studio](https://aistudio.google.com/).
2. Sign in with your Google account.
3. Click on **"Get API key"** to create a free API key.

### 2. Configure the App
1. Open the **Receipts** app on your iPhone or iPad.
2. Tap the **Settings** button on the top-right of the **Dashboard**.
3. Enter your API Key in the **Gemini API Key** field.
4. (Optional) Select your preferred **AI Model** and **Currency**.

## Opening in Xcode (macOS)

This repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`:

```bash
brew install xcodegen
xcodegen generate
open ReceiptsTracker.xcodeproj
```

## Built With
* [Swift](https://www.swift.org/) & [SwiftUI](https://developer.apple.com/xcode/swiftui/) (iOS 26 Liquid Glass)
* [SwiftData](https://developer.apple.com/xcode/swiftdata/) & [Swift Charts](https://developer.apple.com/documentation/charts)
* [VisionKit](https://developer.apple.com/documentation/visionkit)
* [Google Gemini API](https://ai.google.dev/)
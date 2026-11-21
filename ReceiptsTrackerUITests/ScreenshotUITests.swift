import XCTest

@MainActor
final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        if ProcessInfo.processInfo.environment["SCREENSHOT_ORIENTATION"] == "landscape" {
            XCUIDevice.shared.orientation = .landscapeLeft
        } else {
            XCUIDevice.shared.orientation = .portrait
        }
        app = XCUIApplication()
        app.launchArguments = ["--demo-data"]
        app.launch()
    }

    func testCaptureAppScreenshots() {
        // 1. Dashboard ("This Month" is already the default filter and renders a multi-day trend curve)
        _ = app.buttons["This Month"].waitForExistence(timeout: 4)
        briefPause()
        saveScreenshot(named: "01_Dashboard")

        // 2. Open Receipt Detail from Dashboard ("Lidl")
        let lidlButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Lidl'")).firstMatch
        if lidlButton.waitForExistence(timeout: 3) {
            lidlButton.tap()
            briefPause()
            saveScreenshot(named: "02_ReceiptDetail")

            // On compact layout, also capture the Raw Image segmented tab
            let rawImageSegment = app.buttons["Raw Image"]
            if rawImageSegment.waitForExistence(timeout: 1) {
                rawImageSegment.tap()
                briefPause()
                saveScreenshot(named: "03_ReceiptDetail_RawImage")
            }

            // 3. Edit Receipt sheet
            let editButton = app.buttons["Edit"]
            if editButton.waitForExistence(timeout: 2) {
                editButton.tap()
                briefPause()
                saveScreenshot(named: "04_EditReceipt")

                let cancelButton = app.buttons["Cancel"]
                if cancelButton.waitForExistence(timeout: 2) {
                    cancelButton.tap()
                    briefPause()
                }
            }
        }

        // 4. Receipts Tab (List & Search / SplitView on regular width)
        tapTab(named: "Receipts")
        briefPause()

        // On regular-width split view (where the detail placeholder is visible),
        // select Lidl so the side-by-side detail pane is populated.
        if app.staticTexts["Select a Receipt"].waitForExistence(timeout: 1) {
            let lidlCell = app.staticTexts["Lidl"].firstMatch
            if lidlCell.waitForExistence(timeout: 2) {
                lidlCell.tap()
                briefPause()
            }
        }
        saveScreenshot(named: "05_ReceiptsList")

        // 5. Scan Tab (in the bottom floating Liquid Glass tab bar)
        tapTab(named: "Scan")
        briefPause()
        saveScreenshot(named: "06_ScanReceipt")

        // 6. Settings Sheet (opened from top-right of Dashboard)
        tapTab(named: "Dashboard")
        briefPause()
        // If Receipt Detail was still pushed on Dashboard stack, pop back to Dashboard root
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if !app.buttons["Settings"].waitForExistence(timeout: 1), backButton.exists {
            backButton.tap()
            briefPause()
        }
        let settingsButton = app.buttons["Settings"].firstMatch
        if settingsButton.waitForExistence(timeout: 2) {
            settingsButton.tap()
            briefPause()
            saveScreenshot(named: "07_Settings")
        }
    }

    private func briefPause() {
        usleep(300_000)
    }

    private func tapTab(named title: String) {
        let tabBarButton = app.tabBars.buttons[title]
        if tabBarButton.waitForExistence(timeout: 1) {
            tabBarButton.tap()
            return
        }

        let button = app.buttons[title].firstMatch
        if button.waitForExistence(timeout: 2) {
            button.tap()
            return
        }

        // Sidebar fallback on regular width
        let sidebarToggle = app.buttons["ToggleSidebar"].firstMatch
        if sidebarToggle.exists {
            sidebarToggle.tap()
            briefPause()
            let sidebarItem = app.staticTexts[title].firstMatch
            if sidebarItem.waitForExistence(timeout: 1.5) {
                sidebarItem.tap()
            }
        }
    }

    private func saveScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        // Always attach to XCTest results
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also write PNG directly to output directory when configured by CI
        if let outputDir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !outputDir.isEmpty {
            let dirURL = URL(fileURLWithPath: outputDir, isDirectory: true)
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let fileURL = dirURL.appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: fileURL)
        }
    }
}

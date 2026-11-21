import XCTest

@MainActor
final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo-data"]
        app.launch()
    }

    func testCaptureAppScreenshots() {
        // 1. Dashboard ("This Month" is default and renders a multi-day trend curve for demo receipts)
        let thisMonthButton = app.buttons["This Month"]
        if thisMonthButton.waitForExistence(timeout: 5) {
            thisMonthButton.tap()
            sleep(1)
        }
        saveScreenshot(named: "01_Dashboard")

        // 2. Open Receipt Detail from Dashboard ("Lidl")
        let lidlButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Lidl'")).firstMatch
        if lidlButton.waitForExistence(timeout: 5) {
            lidlButton.tap()
            sleep(1)
            saveScreenshot(named: "02_ReceiptDetail")

            // On compact layout, also capture the Raw Image segmented tab
            let rawImageSegment = app.buttons["Raw Image"]
            if rawImageSegment.waitForExistence(timeout: 2) {
                rawImageSegment.tap()
                sleep(1)
                saveScreenshot(named: "03_ReceiptDetail_RawImage")
            }

            // 3. Edit Receipt sheet
            let editButton = app.buttons["Edit"]
            if editButton.waitForExistence(timeout: 3) {
                editButton.tap()
                sleep(1)
                saveScreenshot(named: "04_EditReceipt")

                let cancelButton = app.buttons["Cancel"]
                if cancelButton.waitForExistence(timeout: 3) {
                    cancelButton.tap()
                    sleep(1)
                }
            }
        }

        // 4. Receipts Tab (List & Search / SplitView on regular width)
        tapTab(named: "Receipts")
        sleep(1)

        // On regular-width split view (where the detail placeholder is visible),
        // select Lidl so the side-by-side detail pane is populated.
        if app.staticTexts["Select a Receipt"].waitForExistence(timeout: 2) {
            let lidlCell = app.staticTexts["Lidl"].firstMatch
            if lidlCell.waitForExistence(timeout: 3) {
                lidlCell.tap()
                sleep(1)
            }
        }
        saveScreenshot(named: "05_ReceiptsList")

        // 5. Scan Tab (in the bottom floating Liquid Glass tab bar)
        tapTab(named: "Scan")
        sleep(1)
        saveScreenshot(named: "06_ScanReceipt")

        // 6. Settings Sheet (opened from top-right of Dashboard)
        tapTab(named: "Dashboard")
        sleep(1)
        // If Receipt Detail was still pushed on Dashboard stack, pop back to Dashboard root
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if app.buttons["Settings"].waitForExistence(timeout: 2) == false, backButton.exists {
            backButton.tap()
            sleep(1)
        }
        let settingsButton = app.buttons["Settings"].firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            sleep(1)
            saveScreenshot(named: "07_Settings")
        }
    }

    private func tapTab(named title: String) {
        let tabBarButton = app.tabBars.buttons[title]
        if tabBarButton.waitForExistence(timeout: 2) {
            tabBarButton.tap()
            return
        }

        let button = app.buttons[title].firstMatch
        if button.waitForExistence(timeout: 3) {
            button.tap()
            return
        }

        // Sidebar fallback on regular width
        let sidebarToggle = app.buttons["ToggleSidebar"].firstMatch
        if sidebarToggle.exists {
            sidebarToggle.tap()
            sleep(1)
            let sidebarItem = app.staticTexts[title].firstMatch
            if sidebarItem.waitForExistence(timeout: 2) {
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

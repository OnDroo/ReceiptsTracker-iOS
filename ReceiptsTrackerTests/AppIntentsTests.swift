import AppIntents
import XCTest
@testable import ReceiptsTracker

@MainActor
final class AppIntentsTests: XCTestCase {
    override func tearDown() async throws {
        _ = IntentNavigationBridge.consumePendingTab()
        AppContainer.active = nil
    }

    func testMonthlySpendingSummaryHandlesEmptyState() {
        let fixedNow = DateUtils.parseGeminiDate("2026-11-23 12:00:00")
        let message = MonthlySpendingSummary.buildMessage(
            receipts: [],
            targetCurrency: "EUR",
            now: fixedNow,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(message, "You haven't recorded any receipts this month yet.")
    }

    func testMonthlySpendingSummaryFiltersCurrentMonthAndConvertsCurrency() {
        let fixedNow = DateUtils.parseGeminiDate("2026-11-23 12:00:00")
        let inMonthEur = ReceiptSnapshot(
            id: "r1",
            storeName: "Lidl",
            totalAmount: 50.0,
            dateTimestamp: DateUtils.parseGeminiDate("2026-11-10 10:00:00"),
            currency: "EUR",
            imageFileName: ""
        )
        let inMonthCzk = ReceiptSnapshot(
            id: "r2",
            storeName: "Alza",
            totalAmount: 1000.0, // 1000 * 0.04 = 40.00 EUR
            dateTimestamp: DateUtils.parseGeminiDate("2026-11-18 14:00:00"),
            currency: "CZK",
            imageFileName: ""
        )
        let previousMonth = ReceiptSnapshot(
            id: "r3",
            storeName: "Old Store",
            totalAmount: 999.0,
            dateTimestamp: DateUtils.parseGeminiDate("2026-10-31 23:00:00"),
            currency: "EUR",
            imageFileName: ""
        )

        let message = MonthlySpendingSummary.buildMessage(
            receipts: [inMonthEur, inMonthCzk, previousMonth],
            targetCurrency: "EUR",
            now: fixedNow,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(message.contains("90.00"), "Expected converted EUR total 90.00, got: \(message)")
        XCTAssertTrue(message.contains("2 receipts"), "Expected plural count, got: \(message)")
    }

    func testMonthlySpendingSummaryUsesSingularForOneReceipt() {
        let fixedNow = DateUtils.parseGeminiDate("2026-11-23 12:00:00")
        let single = ReceiptSnapshot(
            id: "r1",
            storeName: "Cafe",
            totalAmount: 12.50,
            dateTimestamp: DateUtils.parseGeminiDate("2026-11-05 09:00:00"),
            currency: "EUR",
            imageFileName: ""
        )

        let message = MonthlySpendingSummary.buildMessage(
            receipts: [single],
            targetCurrency: "EUR",
            now: fixedNow,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(message.contains("1 receipt this month"), "Expected singular noun, got: \(message)")
    }

    func testScanReceiptIntentRequestsScanTabNavigation() async throws {
        let intent = ScanReceiptIntent()
        _ = try await intent.perform()

        XCTAssertEqual(IntentNavigationBridge.consumePendingTab(), .scan)
        XCTAssertNil(IntentNavigationBridge.consumePendingTab())
    }

    func testGetMonthlySpendingIntentReadsActiveContainer() async throws {
        let demo = AppContainer.makeDemo()
        AppContainer.active = demo

        let intent = GetMonthlySpendingIntent()
        let result = try await intent.perform()
        let value = result.value ?? ""

        XCTAssertTrue(value.contains("4 receipts"), "Expected demo monthly summary, got: \(value)")
    }

    func testShortcutsProviderExposesBothShortcuts() {
        XCTAssertEqual(ReceiptsShortcuts.appShortcuts.count, 2)
    }
}

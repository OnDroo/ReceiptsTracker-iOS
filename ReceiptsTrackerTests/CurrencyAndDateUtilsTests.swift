import XCTest
@testable import ReceiptsTracker

final class CurrencyAndDateUtilsTests: XCTestCase {
    func testCurrencyConversionMatchesAndroidRates() {
        XCTAssertEqual(CurrencyUtils.toEur(100, currencyCode: "EUR"), 100, accuracy: 0.001)
        XCTAssertEqual(CurrencyUtils.toEur(100, currencyCode: "USD"), 92, accuracy: 0.001)
        XCTAssertEqual(CurrencyUtils.toEur(100, currencyCode: "CZK"), 4, accuracy: 0.001)
        XCTAssertEqual(CurrencyUtils.toEur(100, currencyCode: "GBP"), 117, accuracy: 0.001)
        XCTAssertEqual(CurrencyUtils.toEur(100, currencyCode: "PLN"), 23, accuracy: 0.001)

        // Same currency is identity
        XCTAssertEqual(CurrencyUtils.convert(42.5, from: "czk", to: "CZK"), 42.5, accuracy: 0.0001)

        // EUR -> CZK
        XCTAssertEqual(CurrencyUtils.convert(10, from: "EUR", to: "CZK"), 253.0, accuracy: 0.001)

        // USD -> EUR
        XCTAssertEqual(CurrencyUtils.convert(50, from: "USD", to: "EUR"), 46.0, accuracy: 0.001)
    }

    func testCurrencyFormattingUsesCurrencySymbol() {
        let formatted = CurrencyUtils.format(24.5, currencyCode: "EUR", locale: Locale(identifier: "en_US"))
        XCTAssertTrue(formatted.contains("€"))
        XCTAssertTrue(formatted.contains("24.50"))
    }

    func testParseGeminiFullDateTime() {
        let parsed = DateUtils.parseGeminiDate("2026-01-08 17:27:00")
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.hour, 17)
        XCTAssertEqual(components.minute, 27)
    }

    func testParseGeminiDateOnlyFallback() {
        let parsed = DateUtils.parseGeminiDate("2025-12-11")
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: parsed)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 11)
    }

    func testParseGeminiInvalidDateUsesFallback() {
        let fallback = Date(timeIntervalSince1970: 1_700_000_000)
        let parsed = DateUtils.parseGeminiDate("not-a-date", fallback: fallback)
        XCTAssertEqual(parsed, fallback)
    }

    func testIconRegistryDefaultMappings() {
        for seed in Category.defaultSeedDefinitions {
            XCTAssertNotEqual(IconRegistry.symbolName(for: seed.iconId), "receipt")
        }
        XCTAssertEqual(IconRegistry.symbolName(for: "unknown_icon"), "receipt")
        XCTAssertEqual(IconRegistry.symbolName(for: nil), "receipt")
    }
}

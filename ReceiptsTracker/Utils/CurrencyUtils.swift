import Foundation

enum CurrencyUtils {
    static let supportedCurrencies: [String] = ["EUR", "USD", "CZK", "GBP", "PLN"]

    /// Value of 1 unit of currency in EUR (matches Android CurrencyUtils)
    private static let toEurRates: [String: Double] = [
        "EUR": 1.0,
        "USD": 0.92,
        "CZK": 0.04,
        "GBP": 1.17,
        "PLN": 0.23
    ]

    /// Value of 1 EUR in target currency (matches Android CurrencyUtils)
    private static let fromEurRates: [String: Double] = [
        "EUR": 1.0,
        "USD": 1.08,
        "CZK": 25.3,
        "GBP": 0.85,
        "PLN": 4.35
    ]

    static func toEur(_ amount: Double, currencyCode: String) -> Double {
        let code = currencyCode.uppercased()
        let rate = toEurRates[code] ?? 1.0
        return amount * rate
    }

    static func convert(_ amount: Double, from fromCurrency: String, to toCurrency: String) -> Double {
        if fromCurrency.caseInsensitiveCompare(toCurrency) == .orderedSame {
            return amount
        }
        let amountInEur = toEur(amount, currencyCode: fromCurrency)
        let target = toCurrency.uppercased()
        if target == "EUR" {
            return amountInEur
        }
        let rate = fromEurRates[target] ?? 1.0
        return amountInEur * rate
    }

    static func format(_ amount: Double, currencyCode: String, locale: Locale = .current) -> String {
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            return String(format: "%.2f", amount)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f %@", amount, code)
    }

    static func symbol(for currencyCode: String, locale: Locale = .current) -> String {
        let code = currencyCode.uppercased()
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }
}

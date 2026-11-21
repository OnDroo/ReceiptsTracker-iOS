import Foundation

enum DateUtils {
    static func formatDateTime(_ date: Date, locale: Locale = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        return "\(dateFormatter.string(from: date)), \(timeFormatter.string(from: date))"
    }

    static func formatDetailDateTime(_ date: Date, locale: Locale = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        return "\(dateFormatter.string(from: date)) • \(timeFormatter.string(from: date))"
    }

    static func formatMonthYear(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    static func formatShortMonthDay(_ date: Date, locale: Locale = Locale(identifier: "en_US_POSIX")) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }

    static func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }

    /// Parses dates returned by Gemini ("YYYY-MM-DD HH:mm:ss", fallback "YYYY-MM-DD", fallback now)
    static func parseGeminiDate(_ dateString: String, fallback: Date = Date()) -> Date {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)

        let fullFormatter = DateFormatter()
        fullFormatter.locale = Locale(identifier: "en_US_POSIX")
        fullFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let parsed = fullFormatter.date(from: trimmed) {
            return parsed
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        if let parsed = dateOnlyFormatter.date(from: trimmed) {
            return parsed
        }

        let isoFormatter = ISO8601DateFormatter()
        if let parsed = isoFormatter.date(from: trimmed) {
            return parsed
        }

        return fallback
    }
}

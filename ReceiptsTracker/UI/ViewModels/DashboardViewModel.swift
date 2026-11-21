import Foundation
import Observation

enum TimeFilter: String, CaseIterable, Identifiable, Sendable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case allTime = "All Time"

    var id: String { rawValue }
}

struct SpendingTrendPoint: Identifiable, Hashable, Sendable {
    let id: Int
    let label: String
    let amount: Double
}

struct CategoryBreakdownItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let totalFormatted: String
    let amount: Double
    let percentage: Double
    let colorIndex: Int
}

struct TransactionRowData: Identifiable, Hashable, Sendable {
    let id: String
    let storeName: String
    let dateString: String
    let amountFormatted: String
    let iconId: String?
    let categoryName: String?
    let matchedItems: [String]
}

@MainActor
@Observable
final class DashboardViewModel {
    private let repository: ReceiptRepositoryProtocol
    private let settingsStore: SettingsStore
    private let calendar: Calendar

    var selectedFilter: TimeFilter = .thisWeek {
        didSet { recompute() }
    }

    private(set) var isLoading: Bool = true
    private(set) var totalSpendingFormatted: String = CurrencyUtils.format(0, currencyCode: "EUR")
    private(set) var receiptCount: Int = 0
    private(set) var trendPoints: [SpendingTrendPoint] = []
    private(set) var dateRangeLabel: String = "No Data"
    private(set) var categoryBreakdown: [CategoryBreakdownItem] = []
    private(set) var recentTransactions: [TransactionRowData] = []

    private var allReceipts: [ReceiptSnapshot] = []
    private var nowProvider: () -> Date

    init(
        repository: ReceiptRepositoryProtocol,
        settingsStore: SettingsStore,
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.settingsStore = settingsStore
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2 // Monday, matching Android Calendar.MONDAY
        self.calendar = mondayCalendar
        self.nowProvider = nowProvider
    }

    func reload() {
        allReceipts = (try? repository.fetchAllReceipts()) ?? []
        recompute()
    }

    func recompute() {
        let targetCurrency = settingsStore.currency
        let now = nowProvider()
        let filtered = filterReceipts(allReceipts, by: selectedFilter, now: now)

        let totalAmount = filtered.reduce(0.0) { partial, item in
            partial + CurrencyUtils.convert(item.totalAmount, from: item.currency, to: targetCurrency)
        }

        totalSpendingFormatted = CurrencyUtils.format(totalAmount, currencyCode: targetCurrency)
        receiptCount = filtered.count

        let (points, label) = calculateTrendPoints(
            receipts: filtered,
            filter: selectedFilter,
            targetCurrency: targetCurrency,
            now: now
        )
        trendPoints = points
        dateRangeLabel = label

        categoryBreakdown = calculateCategoryBreakdown(
            receipts: filtered,
            totalAmount: totalAmount,
            targetCurrency: targetCurrency
        )

        recentTransactions = filtered.prefix(5).map { receipt in
            TransactionRowData(
                id: receipt.id,
                storeName: receipt.storeName,
                dateString: DateUtils.formatDateTime(receipt.dateTimestamp),
                amountFormatted: CurrencyUtils.format(receipt.totalAmount, currencyCode: receipt.currency),
                iconId: receipt.category?.iconId,
                categoryName: receipt.category?.name,
                matchedItems: []
            )
        }

        isLoading = false
    }

    private func filterReceipts(_ receipts: [ReceiptSnapshot], by filter: TimeFilter, now: Date) -> [ReceiptSnapshot] {
        guard filter != .allTime else { return receipts }

        let startDate: Date
        switch filter {
        case .thisWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            startDate = calendar.date(from: components) ?? calendar.startOfDay(for: now)
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            startDate = calendar.date(from: components) ?? calendar.startOfDay(for: now)
        case .thisYear:
            let components = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: components) ?? calendar.startOfDay(for: now)
        case .allTime:
            return receipts
        }

        return receipts.filter { $0.dateTimestamp >= startDate }
    }

    private func calculateTrendPoints(
        receipts: [ReceiptSnapshot],
        filter: TimeFilter,
        targetCurrency: String,
        now: Date
    ) -> ([SpendingTrendPoint], String) {
        guard !receipts.isEmpty else {
            return ([], "No Data")
        }

        switch filter {
        case .thisWeek:
            var buckets = Array(repeating: 0.0, count: 7)
            let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let weekStart = calendar.date(from: weekComponents) ?? calendar.startOfDay(for: now)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? now
            let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

            for receipt in receipts {
                let weekday = calendar.component(.weekday, from: receipt.dateTimestamp)
                let index = (weekday - calendar.firstWeekday + 7) % 7
                if buckets.indices.contains(index) {
                    buckets[index] += CurrencyUtils.convert(receipt.totalAmount, from: receipt.currency, to: targetCurrency)
                }
            }

            let points = buckets.enumerated().map { idx, amount in
                SpendingTrendPoint(id: idx, label: dayLabels[idx], amount: amount)
            }
            let rangeLabel = "\(DateUtils.formatShortMonthDay(weekStart)) – \(DateUtils.formatShortMonthDay(weekEnd))"
            return (points, rangeLabel)

        case .thisMonth:
            let range = calendar.range(of: .day, in: .month, for: now) ?? 1..<31
            let maxDays = range.count
            var buckets = Array(repeating: 0.0, count: maxDays)

            let monthComponents = calendar.dateComponents([.year, .month], from: now)
            let monthStart = calendar.date(from: monthComponents) ?? now
            let monthEnd = calendar.date(byAdding: .day, value: maxDays - 1, to: monthStart) ?? now

            for receipt in receipts {
                let day = calendar.component(.day, from: receipt.dateTimestamp)
                let index = day - 1
                if buckets.indices.contains(index) {
                    buckets[index] += CurrencyUtils.convert(receipt.totalAmount, from: receipt.currency, to: targetCurrency)
                }
            }

            let points = buckets.enumerated().map { idx, amount in
                SpendingTrendPoint(id: idx, label: "\(idx + 1)", amount: amount)
            }
            let rangeLabel = "\(DateUtils.formatShortMonthDay(monthStart)) – \(DateUtils.formatShortMonthDay(monthEnd))"
            return (points, rangeLabel)

        case .thisYear:
            var buckets = Array(repeating: 0.0, count: 12)
            let monthSymbols = calendar.shortMonthSymbols

            for receipt in receipts {
                let month = calendar.component(.month, from: receipt.dateTimestamp) - 1
                if buckets.indices.contains(month) {
                    buckets[month] += CurrencyUtils.convert(receipt.totalAmount, from: receipt.currency, to: targetCurrency)
                }
            }

            let points = buckets.enumerated().map { idx, amount in
                let label = idx < monthSymbols.count ? monthSymbols[idx] : "\(idx + 1)"
                return SpendingTrendPoint(id: idx, label: label, amount: amount)
            }
            return (points, DateUtils.formatYear(now))

        case .allTime:
            guard let minDate = receipts.map(\.dateTimestamp).min(),
                  let maxDate = receipts.map(\.dateTimestamp).max() else {
                return ([], "No Data")
            }

            let minYear = calendar.component(.year, from: minDate)
            let maxYear = calendar.component(.year, from: maxDate)
            let span = max(1, maxYear - minYear + 1)
            var buckets = Array(repeating: 0.0, count: span)

            for receipt in receipts {
                let year = calendar.component(.year, from: receipt.dateTimestamp)
                let index = year - minYear
                if buckets.indices.contains(index) {
                    buckets[index] += CurrencyUtils.convert(receipt.totalAmount, from: receipt.currency, to: targetCurrency)
                }
            }

            let points = buckets.enumerated().map { idx, amount in
                SpendingTrendPoint(id: idx, label: "\(minYear + idx)", amount: amount)
            }
            let rangeLabel = minYear == maxYear
                ? "\(minYear)"
                : "\(DateUtils.formatYear(minDate)) – \(DateUtils.formatYear(maxDate))"
            return (points, rangeLabel)
        }
    }

    private func calculateCategoryBreakdown(
        receipts: [ReceiptSnapshot],
        totalAmount: Double,
        targetCurrency: String
    ) -> [CategoryBreakdownItem] {
        guard totalAmount > 0 else { return [] }

        let grouped = Dictionary(grouping: receipts) { $0.category?.name ?? "Uncategorized" }
        let rawEntries: [(name: String, sum: Double, percentage: Double)] = grouped
            .map { name, list in
                let sum = list.reduce(0.0) { partial, receipt in
                    partial + CurrencyUtils.convert(receipt.totalAmount, from: receipt.currency, to: targetCurrency)
                }
                return (name: name, sum: sum, percentage: sum / totalAmount)
            }
            .sorted { $0.sum > $1.sum }

        // Group categories under 7% into "Others" (matches Android threshold = 0.07)
        let threshold = 0.07
        let big = rawEntries.filter { $0.percentage >= threshold }
        let small = rawEntries.filter { $0.percentage < threshold }

        var finalEntries = big
        if !small.isEmpty {
            let smallSum = small.reduce(0.0) { $0 + $1.sum }
            finalEntries.append((name: "Others", sum: smallSum, percentage: smallSum / totalAmount))
        }

        return finalEntries.enumerated().map { index, entry in
            CategoryBreakdownItem(
                id: "\(index)-\(entry.name)",
                name: entry.name,
                totalFormatted: CurrencyUtils.format(entry.sum, currencyCode: targetCurrency),
                amount: entry.sum,
                percentage: entry.percentage,
                colorIndex: index
            )
        }
    }
}

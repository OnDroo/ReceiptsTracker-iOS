import AppIntents
import Foundation

extension Notification.Name {
    static let openRequestedTab = Notification.Name("link.ondrov.receipts.openRequestedTab")
}

@MainActor
enum IntentNavigationBridge {
    static var pendingTab: AppTab?

    static func request(_ tab: AppTab) {
        pendingTab = tab
        NotificationCenter.default.post(name: .openRequestedTab, object: nil)
    }

    static func consumePendingTab() -> AppTab? {
        defer { pendingTab = nil }
        return pendingTab
    }
}

enum MonthlySpendingSummary {
    static func buildMessage(
        receipts: [ReceiptSnapshot],
        targetCurrency: String,
        calendar: Calendar = .current,
        now: Date = Date(),
        locale: Locale = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month], from: now)
        let monthStart = calendar.date(from: components) ?? calendar.startOfDay(for: now)

        let monthlyReceipts = receipts.filter { $0.dateTimestamp >= monthStart }
        guard !monthlyReceipts.isEmpty else {
            return "You haven't recorded any receipts this month yet."
        }

        let total = monthlyReceipts.reduce(0.0) { partial, receipt in
            partial + CurrencyUtils.convert(
                receipt.totalAmount,
                from: receipt.currency,
                to: targetCurrency
            )
        }
        let formattedTotal = CurrencyUtils.format(total, currencyCode: targetCurrency, locale: locale)
        let noun = monthlyReceipts.count == 1 ? "receipt" : "receipts"
        return "You've spent \(formattedTotal) across \(monthlyReceipts.count) \(noun) this month."
    }
}

struct GetMonthlySpendingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Monthly Spending"
    static var description = IntentDescription(
        "Summarizes your total receipt spending for the current month in your preferred currency."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let receipts: [ReceiptSnapshot]
        let targetCurrency: String

        if let active = AppContainer.active {
            receipts = (try? active.receiptRepository.fetchAllReceipts()) ?? []
            targetCurrency = active.settingsStore.currency
        } else {
            let modelContainer = try PersistenceController.makeModelContainer(inMemory: false)
            let repository = SwiftDataReceiptRepository(modelContext: modelContainer.mainContext)
            receipts = (try? repository.fetchAllReceipts()) ?? []
            targetCurrency = UserDefaults.standard.string(forKey: SettingsStore.Keys.currency)
                ?? SettingsStore.Defaults.currency
        }

        let message = MonthlySpendingSummary.buildMessage(
            receipts: receipts,
            targetCurrency: targetCurrency
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}

struct ScanReceiptIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Receipt"
    static var description = IntentDescription(
        "Opens Receipts directly to the scanner so you can capture or import a new receipt."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentNavigationBridge.request(.scan)
        return .result(dialog: "Opening receipt scanner.")
    }
}

struct ReceiptsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetMonthlySpendingIntent(),
            phrases: [
                "Show monthly spending in \(.applicationName)",
                "How much did I spend this month in \(.applicationName)"
            ],
            shortTitle: "Monthly Spending",
            systemImageName: "chart.bar.xaxis"
        )
        AppShortcut(
            intent: ScanReceiptIntent(),
            phrases: [
                "Scan a receipt in \(.applicationName)",
                "Add a receipt in \(.applicationName)"
            ],
            shortTitle: "Scan Receipt",
            systemImageName: "doc.viewfinder"
        )
    }
}

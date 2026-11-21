import Foundation
import Observation

struct ReceiptMonthSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [TransactionRowData]
}

@MainActor
@Observable
final class ReceiptListViewModel {
    private let repository: ReceiptRepositoryProtocol
    private let fileStorage: FileStorageHelper

    var searchQuery: String = "" {
        didSet { recompute() }
    }

    var selectedCategoryId: String? = nil {
        didSet { recompute() }
    }

    private(set) var isLoading: Bool = true
    private(set) var sections: [ReceiptMonthSection] = []
    private(set) var totalResultsCount: Int = 0
    private(set) var availableCategories: [CategorySnapshot] = []

    private var allReceipts: [ReceiptSnapshot] = []

    init(
        repository: ReceiptRepositoryProtocol,
        fileStorage: FileStorageHelper = .shared
    ) {
        self.repository = repository
        self.fileStorage = fileStorage
    }

    func reload() {
        allReceipts = (try? repository.fetchAllReceipts()) ?? []
        availableCategories = (try? repository.fetchAllCategories()) ?? []
        recompute()
    }

    func toggleCategory(_ categoryId: String?) {
        if categoryId == nil {
            selectedCategoryId = nil
        } else if selectedCategoryId == categoryId {
            selectedCategoryId = nil
        } else {
            selectedCategoryId = categoryId
        }
    }

    func deleteReceipt(id: String) {
        if let receipt = allReceipts.first(where: { $0.id == id }) {
            fileStorage.deleteFile(fileName: receipt.imageFileName)
        }
        try? repository.deleteReceipt(id: id)
        reload()
    }

    func recompute() {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = allReceipts.filter { receipt in
            let matchesSearch: Bool
            if trimmedQuery.isEmpty {
                matchesSearch = true
            } else {
                let storeMatches = receipt.storeName.localizedCaseInsensitiveContains(trimmedQuery)
                let itemMatches = receipt.items.contains { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
                matchesSearch = storeMatches || itemMatches
            }

            let matchesCategory = selectedCategoryId == nil || receipt.category?.id == selectedCategoryId
            return matchesSearch && matchesCategory
        }

        let sorted = filtered.sorted { $0.dateTimestamp > $1.dateTimestamp }

        // Preserve descending month order explicitly
        var orderedKeys: [String] = []
        var groupedMap: [String: [TransactionRowData]] = [:]

        for receipt in sorted {
            let monthHeader = DateUtils.formatMonthYear(receipt.dateTimestamp)
            if groupedMap[monthHeader] == nil {
                orderedKeys.append(monthHeader)
                groupedMap[monthHeader] = []
            }

            let matchedItems: [String]
            if !trimmedQuery.isEmpty {
                matchedItems = receipt.items
                    .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
                    .map { item in
                        if item.quantity > 1.0 {
                            let qtyString = item.quantity.truncatingRemainder(dividingBy: 1) == 0
                                ? "\(Int(item.quantity))"
                                : String(format: "%.1f", item.quantity)
                            return "\(item.name) (\(qtyString)x)"
                        }
                        return item.name
                    }
            } else {
                matchedItems = []
            }

            let row = TransactionRowData(
                id: receipt.id,
                storeName: receipt.storeName,
                dateString: DateUtils.formatDateTime(receipt.dateTimestamp),
                amountFormatted: CurrencyUtils.format(receipt.totalAmount, currencyCode: receipt.currency),
                iconId: receipt.category?.iconId,
                categoryName: receipt.category?.name,
                matchedItems: matchedItems
            )
            groupedMap[monthHeader, default: []].append(row)
        }

        sections = orderedKeys.map { key in
            ReceiptMonthSection(id: key, title: key, items: groupedMap[key] ?? [])
        }
        totalResultsCount = filtered.count
        isLoading = false
    }
}

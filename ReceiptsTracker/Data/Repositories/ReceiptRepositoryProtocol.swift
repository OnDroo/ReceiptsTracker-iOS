import Foundation

extension Notification.Name {
    static let receiptsDidChange = Notification.Name("link.ondrov.receipts.receiptsDidChange")
}

@MainActor
protocol ReceiptRepositoryProtocol {
    func fetchAllReceipts() throws -> [ReceiptSnapshot]
    func fetchReceipt(id: String) throws -> ReceiptSnapshot?
    func saveReceipt(_ receipt: ReceiptSnapshot) throws
    func updateReceipt(_ receipt: ReceiptSnapshot) throws
    func deleteReceipt(id: String) throws
    func fetchAllCategories() throws -> [CategorySnapshot]
}

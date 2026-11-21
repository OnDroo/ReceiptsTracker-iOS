import Foundation
import Observation
import Photos
import UIKit

@MainActor
@Observable
final class ReceiptDetailViewModel {
    private let receiptId: String
    private let repository: ReceiptRepositoryProtocol
    private let fileStorage: FileStorageHelper

    private(set) var receipt: ReceiptSnapshot?
    private(set) var availableCategories: [CategorySnapshot] = []
    private(set) var isLoading: Bool = true
    var statusMessage: String?

    init(
        receiptId: String,
        repository: ReceiptRepositoryProtocol,
        fileStorage: FileStorageHelper = .shared
    ) {
        self.receiptId = receiptId
        self.repository = repository
        self.fileStorage = fileStorage
    }

    func reload() {
        receipt = try? repository.fetchReceipt(id: receiptId)
        availableCategories = (try? repository.fetchAllCategories()) ?? []
        isLoading = false
    }

    func receiptImage() -> UIImage? {
        guard let fileName = receipt?.imageFileName, !fileName.isEmpty else { return nil }
        return fileStorage.loadImage(fileName: fileName)
    }

    func receiptImageURL() -> URL? {
        guard let fileName = receipt?.imageFileName, !fileName.isEmpty else { return nil }
        let url = fileStorage.fileURL(for: fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func updateReceipt(_ updated: ReceiptSnapshot) {
        try? repository.updateReceipt(updated)
        reload()
    }

    func deleteReceipt() {
        if let fileName = receipt?.imageFileName {
            fileStorage.deleteFile(fileName: fileName)
        }
        try? repository.deleteReceipt(id: receiptId)
        receipt = nil
    }

    func saveImageToPhotoLibrary() async {
        guard let image = receiptImage() else {
            statusMessage = "Receipt image not found."
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            statusMessage = "Photo Library access denied. Enable it in Settings."
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            statusMessage = "Saved to Photos"
        } catch {
            statusMessage = "Failed to save image: \(error.localizedDescription)"
        }
    }
}

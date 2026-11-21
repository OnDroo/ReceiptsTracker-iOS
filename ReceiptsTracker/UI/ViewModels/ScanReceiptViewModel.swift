import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ScanReceiptViewModel {
    private let geminiService: GeminiService
    private let fileStorage: FileStorageHelper

    private(set) var isAnalyzing: Bool = false
    var showRetryDialog: Bool = false
    private(set) var lastErrorMessage: String = ""
    private(set) var isApiKeyMissingOrWrong: Bool = false
    private(set) var analyzedReceiptId: String?

    private var pendingImageURL: URL?

    init(
        geminiService: GeminiService,
        fileStorage: FileStorageHelper = .shared
    ) {
        self.geminiService = geminiService
        self.fileStorage = fileStorage
    }

    func analyzeImage(_ image: UIImage) {
        do {
            let fileURL = try fileStorage.saveJPEGImage(image)
            pendingImageURL = fileURL
            performAnalysis(fileURL: fileURL)
        } catch {
            lastErrorMessage = error.localizedDescription
            isApiKeyMissingOrWrong = false
            showRetryDialog = true
        }
    }

    func analyzeImageData(_ data: Data) {
        if let image = UIImage(data: data) {
            analyzeImage(image)
            return
        }

        do {
            let fileURL = try fileStorage.saveImageData(data)
            pendingImageURL = fileURL
            performAnalysis(fileURL: fileURL)
        } catch {
            lastErrorMessage = error.localizedDescription
            isApiKeyMissingOrWrong = false
            showRetryDialog = true
        }
    }

    func retryAnalysis() {
        showRetryDialog = false
        guard let fileURL = pendingImageURL else { return }
        performAnalysis(fileURL: fileURL)
    }

    func dismissErrorAndDiscard() {
        if let fileURL = pendingImageURL {
            fileStorage.deleteFile(at: fileURL)
        }
        pendingImageURL = nil
        showRetryDialog = false
    }

    private func performAnalysis(fileURL: URL) {
        Task {
            isAnalyzing = true
            defer { isAnalyzing = false }

            do {
                let newReceiptId = try await geminiService.analyzeReceipt(imageURL: fileURL)
                pendingImageURL = nil
                analyzedReceiptId = newReceiptId
            } catch let error as GeminiServiceError {
                isApiKeyMissingOrWrong = error.isApiKeyIssue
                lastErrorMessage = error.friendlyMessage
                showRetryDialog = true
            } catch {
                let message = error.localizedDescription
                isApiKeyMissingOrWrong = message.localizedCaseInsensitiveContains("API key")
                lastErrorMessage = message.count > 200 ? String(message.prefix(200)) + "..." : message
                showRetryDialog = true
            }
        }
    }
}

import Foundation
import UIKit

final class FileStorageHelper: Sendable {
    static let shared = FileStorageHelper()

    private let baseDirectory: URL

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            self.baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        }
    }

    func fileURL(for fileName: String) -> URL {
        baseDirectory.appendingPathComponent(fileName)
    }

    func saveJPEGImage(_ image: UIImage, compressionQuality: CGFloat = 0.85, id: String = UUID().uuidString) throws -> URL {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw NSError(
                domain: "FileStorageHelper",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode image as JPEG."]
            )
        }
        return try saveImageData(data, id: id)
    }

    func saveImageData(_ data: Data, id: String = UUID().uuidString) throws -> URL {
        let fileName = "\(id).jpg"
        let destinationURL = fileURL(for: fileName)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try data.write(to: destinationURL, options: [.atomic])
        return destinationURL
    }

    func loadImage(fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func deleteFile(fileName: String) {
        guard !fileName.isEmpty else { return }
        deleteFile(at: fileURL(for: fileName))
    }

    func deleteFile(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

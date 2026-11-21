import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScanComplete: (UIImage) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onScanComplete: onScanComplete,
            onCancel: onCancel,
            onError: onError
        )
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScanComplete: (UIImage) -> Void
        private let onCancel: () -> Void
        private let onError: (Error) -> Void

        init(
            onScanComplete: @escaping (UIImage) -> Void,
            onCancel: @escaping () -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.onScanComplete = onScanComplete
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                onCancel()
                return
            }
            let image = scan.imageOfPage(at: 0)
            onScanComplete(image)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onError(error)
        }
    }
}

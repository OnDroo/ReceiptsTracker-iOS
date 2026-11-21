import SwiftUI
import UIKit

struct FullScreenImageView: View {
    let image: UIImage
    let onSaveToPhotos: (() -> Void)?
    let onDismiss: () -> Void

    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(currentScale)
                    .offset(offset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let proposed = lastScale * value.magnification
                                currentScale = min(max(proposed, 1.0), 4.0)
                                if currentScale <= 1.01 {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                            .onEnded { _ in
                                lastScale = currentScale
                                clampOffset(in: geometry.size)
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard currentScale > 1.0 else { return }
                                let proposed = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = clamped(proposed, in: geometry.size)
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            if currentScale > 1.0 {
                                currentScale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                currentScale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }

                VStack {
                    HStack {
                        AdaptiveGlassContainer(spacing: 12) {
                            HStack(spacing: 12) {
                                Button(action: onDismiss) {
                                    Label("Close", systemImage: "xmark")
                                        .labelStyle(.iconOnly)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                }
                                .adaptiveGlassCapsule(tint: .black.opacity(0.35), interactive: true)
                                .accessibilityLabel("Close full screen image")

                                Spacer()

                                if let onSaveToPhotos {
                                    Button(action: onSaveToPhotos) {
                                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .frame(height: 44)
                                    }
                                    .adaptiveGlassCapsule(tint: .black.opacity(0.35), interactive: true)
                                }
                            }
                        }
                    }
                    .padding()

                    Spacer()
                }
            }
        }
    }

    private func clampOffset(in size: CGSize) {
        offset = clamped(offset, in: size)
        lastOffset = offset
    }

    private func clamped(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let maxX = max(0, (size.width * (currentScale - 1.0)) / 2.0)
        let maxY = max(0, (size.height * (currentScale - 1.0)) / 2.0)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}

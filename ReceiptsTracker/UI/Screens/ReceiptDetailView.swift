import SwiftUI

struct ReceiptDetailView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let receiptId: String
    let onDeleted: () -> Void

    private enum DetailSegment: String, CaseIterable, Identifiable {
        case items = "Items"
        case image = "Raw Image"
        var id: String { rawValue }
    }

    @State private var viewModel: ReceiptDetailViewModel?
    @State private var selectedSegment: DetailSegment = .items
    @State private var isShowingEditSheet: Bool = false
    @State private var isShowingDeleteConfirmation: Bool = false
    @State private var isShowingFullScreenImage: Bool = false
    @State private var bannerMessage: String?

    var body: some View {
        Group {
            if let viewModel {
                if let receipt = viewModel.receipt {
                    detailBody(receipt: receipt, viewModel: viewModel)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.groupedBackground)
                } else {
                    ContentUnavailableView(
                        "Receipt Not Found",
                        systemImage: "doc.questionmark",
                        description: Text("This receipt may have been deleted.")
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.groupedBackground)
            }
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let viewModel, viewModel.receipt != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await viewModel.saveImageToPhotoLibrary()
                                if let msg = viewModel.statusMessage {
                                    showBanner(msg)
                                    viewModel.statusMessage = nil
                                }
                            }
                        } label: {
                            Label("Save Image to Photos", systemImage: "square.and.arrow.down")
                        }
                        .disabled(viewModel.receiptImage() == nil)

                        if let imageURL = viewModel.receiptImageURL() {
                            ShareLink(item: imageURL) {
                                Label("Share Receipt Image", systemImage: "square.and.arrow.up")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("Delete Receipt", systemImage: "trash")
                        }
                    } label: {
                        Label("More Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Receipt?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Receipt", role: .destructive) {
                viewModel?.deleteReceipt()
                onDeleted()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. The receipt and its scan image will be permanently removed.")
        }
        .sheet(isPresented: $isShowingEditSheet) {
            if let viewModel, let receipt = viewModel.receipt {
                EditReceiptView(
                    originalReceipt: receipt,
                    availableCategories: viewModel.availableCategories,
                    onSave: { updated in
                        viewModel.updateReceipt(updated)
                        isShowingEditSheet = false
                    },
                    onCancel: {
                        isShowingEditSheet = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingFullScreenImage) {
            if let viewModel, let image = viewModel.receiptImage() {
                FullScreenImageView(
                    image: image,
                    onSaveToPhotos: {
                        Task {
                            await viewModel.saveImageToPhotoLibrary()
                            if let msg = viewModel.statusMessage {
                                showBanner(msg)
                                viewModel.statusMessage = nil
                            }
                        }
                    },
                    onDismiss: {
                        isShowingFullScreenImage = false
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let bannerMessage {
                Text(bannerMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .adaptiveGlassCapsule(interactive: false)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: receiptId) {
            let vm = ReceiptDetailViewModel(
                receiptId: receiptId,
                repository: container.receiptRepository,
                fileStorage: container.fileStorage
            )
            vm.reload()
            viewModel = vm
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDidChange)) { _ in
            viewModel?.reload()
        }
    }

    @ViewBuilder
    private func detailBody(receipt: ReceiptSnapshot, viewModel: ReceiptDetailViewModel) -> some View {
        let isRegularWidth = horizontalSizeClass == .regular

        if isRegularWidth {
            // Unfolded iPhone Duo / iPad: side-by-side items and raw receipt scan
            ScrollView {
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 18) {
                        headerCard(receipt: receipt)
                        itemsCard(receipt: receipt)
                    }
                    .frame(maxWidth: .infinity)

                    rawImageCard(image: viewModel.receiptImage())
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(AppTheme.groupedBackground)
        } else {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard(receipt: receipt)

                    Picker("View Mode", selection: $selectedSegment) {
                        ForEach(DetailSegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedSegment {
                    case .items:
                        itemsCard(receipt: receipt)
                    case .image:
                        rawImageCard(image: viewModel.receiptImage())
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.groupedBackground)
        }
    }

    private func headerCard(receipt: ReceiptSnapshot) -> some View {
        let iconTint = IconRegistry.tintColor(for: receipt.category?.iconId)

        return VStack(spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: IconRegistry.symbolName(for: receipt.category?.iconId))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 44, height: 44)
                    .background(iconTint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(receipt.storeName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(DateUtils.formatDetailDateTime(receipt.dateTimestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let categoryName = receipt.category?.name {
                    Text(categoryName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(iconTint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(iconTint.opacity(0.14), in: Capsule())
                }
            }

            VStack(spacing: 4) {
                Text(CurrencyUtils.format(receipt.totalAmount, currencyCode: receipt.currency))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("Total Amount")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            if receipt.metadata.hasAnyValue {
                Divider()

                HStack(spacing: 16) {
                    if let payment = receipt.metadata.paymentMethod, !payment.isEmpty {
                        Label(payment, systemImage: "creditcard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let txId = receipt.metadata.transactionId, !txId.isEmpty {
                        Label(txId, systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .nativeCardSurface(cornerRadius: 24)
    }

    private func itemsCard(receipt: ReceiptSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Purchased Items")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(receipt.items.count) \(receipt.items.count == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if receipt.items.isEmpty {
                ContentUnavailableView(
                    "No Line Items",
                    systemImage: "bag",
                    description: Text("Tap Edit to add items to this receipt.")
                )
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
                        receiptItemRow(item: item, currency: receipt.currency)
                            .padding(.vertical, 8)

                        if index < receipt.items.count - 1 {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nativeCardSurface(cornerRadius: 22)
    }

    private func receiptItemRow(item: ReceiptItemSnapshot, currency: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bag.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(AppTheme.tertiaryBackground, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                let qtyText = item.quantity.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(item.quantity))"
                    : String(format: "%.2f", item.quantity)
                let unitText = (item.unit?.isEmpty == false) ? item.unit! : "x"
                Text("\(qtyText) \(unitText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(CurrencyUtils.format(item.price, currencyCode: currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private func rawImageCard(image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Receipt Scan")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if image != nil {
                    Button {
                        isShowingFullScreenImage = true
                    } label: {
                        Label("Zoom", systemImage: "plus.magnifyingglass")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            if let image {
                Button {
                    isShowingFullScreenImage = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 320, maxHeight: 540)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(10)
                                .adaptiveGlassCapsule(interactive: false)
                                .padding(12)
                        }
                }
                .buttonStyle(.plain)
            } else {
                ContentUnavailableView(
                    "No Image Available",
                    systemImage: "photo",
                    description: Text("The original receipt image is not stored on this device.")
                )
                .frame(minHeight: 240)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nativeCardSurface(cornerRadius: 22)
    }

    private func showBanner(_ message: String) {
        withAnimation(.snappy) {
            bannerMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation(.snappy) {
                    if bannerMessage == message {
                        bannerMessage = nil
                    }
                }
            }
        }
    }
}

#Preview {
    let container = AppContainer.preview
    NavigationStack {
        ReceiptDetailView(receiptId: "preview-1", onDeleted: {})
    }
    .environment(container)
}

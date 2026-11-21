import SwiftUI

struct ReceiptListView: View {
    @Environment(AppContainer.self) private var container

    @Binding var selectedReceiptId: String?
    let usesSplitSelection: Bool
    let onSelectReceipt: (String) -> Void
    let onScanTap: () -> Void

    @State private var viewModel: ReceiptListViewModel?

    var body: some View {
        Group {
            if let viewModel {
                listContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.groupedBackground)
            }
        }
        .navigationTitle("Receipts")
        .toolbar(usesSplitSelection ? .visible : .hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                let vm = ReceiptListViewModel(
                    repository: container.receiptRepository,
                    fileStorage: container.fileStorage
                )
                vm.reload()
                viewModel = vm
            } else {
                viewModel?.reload()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDidChange)) { _ in
            viewModel?.reload()
        }
    }

    @ViewBuilder
    private func listContent(viewModel: ReceiptListViewModel) -> some View {
        @Bindable var bindableVM = viewModel

        if usesSplitSelection {
            listBody(viewModel: viewModel, searchQuery: $bindableVM.searchQuery)
                .searchable(
                    text: $bindableVM.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search stores or items…"
                )
        } else {
            listBody(viewModel: viewModel, searchQuery: $bindableVM.searchQuery)
        }
    }

    private func listBody(viewModel: ReceiptListViewModel, searchQuery: Binding<String>) -> some View {
        VStack(spacing: 0) {
            if !usesSplitSelection {
                compactHeader(searchQuery: searchQuery)
            }

            categoryFilterBar(viewModel: viewModel)

            if viewModel.sections.isEmpty {
                emptyState(viewModel: viewModel)
            } else if usesSplitSelection {
                List(selection: $selectedReceiptId) {
                    receiptSections(viewModel: viewModel)
                }
                .listStyle(.insetGrouped)
            } else {
                List {
                    receiptSections(viewModel: viewModel)
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(AppTheme.groupedBackground)
    }

    private func compactHeader(searchQuery: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Receipts")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.top, 4)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Search stores or items…", text: searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !searchQuery.wrappedValue.isEmpty {
                    Button {
                        searchQuery.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func categoryFilterBar(viewModel: ReceiptListViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            AdaptiveGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    let isAllSelected = viewModel.selectedCategoryId == nil
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            viewModel.toggleCategory(nil)
                        }
                    } label: {
                        Label("All", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline.weight(isAllSelected ? .semibold : .medium))
                            .foregroundStyle(isAllSelected ? Color.accentColor : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                    }
                    .adaptiveGlassCapsule(
                        tint: isAllSelected ? Color.accentColor.opacity(0.22) : nil,
                        interactive: true
                    )

                    ForEach(viewModel.availableCategories) { category in
                        let isSelected = viewModel.selectedCategoryId == category.id
                        let tint = IconRegistry.tintColor(for: category.iconId)
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                viewModel.toggleCategory(category.id)
                            }
                        } label: {
                            Label(category.name, systemImage: IconRegistry.symbolName(for: category.iconId))
                                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? tint : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                        }
                        .adaptiveGlassCapsule(
                            tint: isSelected ? tint.opacity(0.22) : nil,
                            interactive: true
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private func receiptSections(viewModel: ReceiptListViewModel) -> some View {
        ForEach(viewModel.sections) { section in
            Section {
                ForEach(section.items) { item in
                    if usesSplitSelection {
                        TransactionRowView(item: item)
                            .tag(item.id)
                    } else {
                        Button {
                            onSelectReceipt(item.id)
                        } label: {
                            HStack(spacing: 8) {
                                TransactionRowView(item: item)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        let receiptId = section.items[idx].id
                        if selectedReceiptId == receiptId {
                            selectedReceiptId = nil
                        }
                        viewModel.deleteReceipt(id: receiptId)
                    }
                }
            } header: {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private func emptyState(viewModel: ReceiptListViewModel) -> some View {
        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: viewModel.searchQuery)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.selectedCategoryId != nil {
            ContentUnavailableView {
                Label("No Receipts in Category", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Try selecting another category or clearing the filter.")
            } actions: {
                Button("Show All Receipts") {
                    viewModel.toggleCategory(nil)
                }
                .adaptiveGlassButtonStyle(prominent: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("No Receipts Yet", systemImage: "doc.text.viewfinder")
            } description: {
                Text("Scan a paper receipt or import a photo to get started.")
            } actions: {
                Button(action: onScanTap) {
                    Label("Scan Receipt", systemImage: "doc.viewfinder")
                }
                .adaptiveGlassButtonStyle(prominent: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    let container = AppContainer.preview
    NavigationStack {
        ReceiptListView(
            selectedReceiptId: .constant(nil),
            usesSplitSelection: false,
            onSelectReceipt: { _ in },
            onScanTap: {}
        )
    }
    .environment(container)
}

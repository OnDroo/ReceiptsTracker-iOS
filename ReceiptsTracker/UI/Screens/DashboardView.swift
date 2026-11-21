import SwiftUI

struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onOpenReceipts: () -> Void
    let onSelectReceipt: (String) -> Void
    let onScanTap: () -> Void

    @State private var viewModel: DashboardViewModel?

    var body: some View {
        Group {
            if let viewModel {
                dashboardScrollContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.groupedBackground)
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onScanTap) {
                    Label("Scan Receipt", systemImage: "doc.viewfinder")
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = DashboardViewModel(
                    repository: container.receiptRepository,
                    settingsStore: container.settingsStore
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
        .onChange(of: container.settingsStore.currency) { _, _ in
            viewModel?.recompute()
        }
    }

    @ViewBuilder
    private func dashboardScrollContent(viewModel: DashboardViewModel) -> some View {
        let isRegularWidth = horizontalSizeClass == .regular

        ScrollView {
            VStack(spacing: 18) {
                timeFilterStrip(viewModel: viewModel)

                DashboardSummarySection(
                    totalSpending: viewModel.totalSpendingFormatted,
                    receiptCount: viewModel.receiptCount,
                    onTap: onOpenReceipts
                )

                if isRegularWidth {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        SpendingTrendsCard(
                            points: viewModel.trendPoints,
                            dateRangeLabel: viewModel.dateRangeLabel,
                            totalFormatted: viewModel.totalSpendingFormatted,
                            onTap: onOpenReceipts
                        )

                        CategoryBreakdownCard(
                            breakdown: viewModel.categoryBreakdown,
                            totalFormatted: viewModel.totalSpendingFormatted,
                            onTap: onOpenReceipts
                        )
                    }
                } else {
                    SpendingTrendsCard(
                        points: viewModel.trendPoints,
                        dateRangeLabel: viewModel.dateRangeLabel,
                        totalFormatted: viewModel.totalSpendingFormatted,
                        onTap: onOpenReceipts
                    )

                    CategoryBreakdownCard(
                        breakdown: viewModel.categoryBreakdown,
                        totalFormatted: viewModel.totalSpendingFormatted,
                        onTap: onOpenReceipts
                    )
                }

                recentTransactionsCard(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .background(AppTheme.groupedBackground)
        .overlay(alignment: .bottomTrailing) {
            floatingScanButton
        }
    }

    private func timeFilterStrip(viewModel: DashboardViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            AdaptiveGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(TimeFilter.allCases) { filter in
                        let isSelected = viewModel.selectedFilter == filter
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                viewModel.selectedFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .adaptiveGlassCapsule(
                            tint: isSelected ? Color.accentColor.opacity(0.22) : nil,
                            interactive: true
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func recentTransactionsCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpenReceipts) {
                HStack {
                    Text("Transactions (\(viewModel.selectedFilter.rawValue))")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)

            if viewModel.recentTransactions.isEmpty {
                ContentUnavailableView {
                    Label("No Transactions", systemImage: "tray")
                        .font(.subheadline)
                } description: {
                    Text("No receipts found for \(viewModel.selectedFilter.rawValue.lowercased()).")
                        .font(.caption)
                }
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentTransactions.enumerated()), id: \.element.id) { index, item in
                        Button {
                            onSelectReceipt(item.id)
                        } label: {
                            TransactionRowView(item: item)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.recentTransactions.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nativeCardSurface(cornerRadius: 22)
    }

    private var floatingScanButton: some View {
        AdaptiveGlassContainer {
            Button(action: onScanTap) {
                Label("Scan", systemImage: "doc.viewfinder")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .adaptiveGlassButtonStyle(prominent: true)
            .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }
}

#Preview {
    let container = AppContainer.preview
    NavigationStack {
        DashboardView(
            onOpenReceipts: {},
            onSelectReceipt: { _ in },
            onScanTap: {}
        )
    }
    .environment(container)
}

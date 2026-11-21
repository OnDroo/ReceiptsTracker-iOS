import Charts
import SwiftUI

// MARK: - Summary Stat Cards

struct DashboardSummarySection: View {
    let totalSpending: String
    let receiptCount: Int
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            DashboardStatCard(
                title: "Total Spending",
                value: totalSpending,
                systemImage: "creditcard.fill",
                tint: .blue,
                onTap: onTap
            )

            DashboardStatCard(
                title: "Receipts Scanned",
                value: "\(receiptCount)",
                systemImage: "doc.text.fill",
                tint: .indigo,
                onTap: onTap
            )
        }
    }
}

struct DashboardStatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.14), in: Circle())

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(value)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nativeCardSurface(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spending Trends Card (Swift Charts)

struct SpendingTrendsCard: View {
    let points: [SpendingTrendPoint]
    let dateRangeLabel: String
    let totalFormatted: String
    let onTap: () -> Void

    private var hasSpendingData: Bool {
        points.contains { $0.amount > 0 }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spending Trends")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(totalFormatted)
                            .font(.title.bold())
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Label(dateRangeLabel, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                if !hasSpendingData {
                    ContentUnavailableView {
                        Label("No Spending Data", systemImage: "chart.xyaxis.line")
                            .font(.subheadline)
                    } description: {
                        Text("Scan a receipt to see your spending curve.")
                            .font(.caption)
                    }
                    .frame(height: 140)
                } else {
                    Chart(points) { point in
                        AreaMark(
                            x: .value("Period", point.id),
                            y: .value("Spent", point.amount)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.32), Color.accentColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Period", point.id),
                            y: .value("Spent", point.amount)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Color.accentColor)

                        if points.count == 1 {
                            PointMark(
                                x: .value("Period", point.id),
                                y: .value("Spent", point.amount)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: min(points.count, 6))) { value in
                            if let idx = value.as(Int.self), points.indices.contains(idx) {
                                AxisValueLabel {
                                    Text(points[idx].label)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color.secondary.opacity(0.25))
                            AxisValueLabel()
                                .font(.caption2)
                        }
                    }
                    .frame(height: 150)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nativeCardSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Breakdown Donut Card (Swift Charts SectorMark)

struct CategoryBreakdownCard: View {
    let breakdown: [CategoryBreakdownItem]
    let totalFormatted: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Spending by Category")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                if breakdown.isEmpty {
                    ContentUnavailableView {
                        Label("No Categories Yet", systemImage: "chart.pie")
                            .font(.subheadline)
                    } description: {
                        Text("Your spending breakdown will appear here.")
                            .font(.caption)
                    }
                    .frame(height: 140)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 20) {
                            donutChart
                            legendList
                        }

                        VStack(spacing: 16) {
                            donutChart
                            legendList
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nativeCardSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }

    private var donutChart: some View {
        Chart(breakdown) { item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.66),
                angularInset: 2.0
            )
            .cornerRadius(6)
            .foregroundStyle(AppTheme.chartColor(at: item.colorIndex))
        }
        .chartLegend(.hidden)
        .frame(width: 140, height: 140)
        .overlay {
            VStack(spacing: 2) {
                Text("Total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(totalFormatted)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
            }
        }
    }

    private var legendList: some View {
        VStack(spacing: 10) {
            ForEach(breakdown) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.chartColor(at: item.colorIndex))
                        .frame(width: 10, height: 10)

                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text("\(Int((item.percentage * 100).rounded()))%")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

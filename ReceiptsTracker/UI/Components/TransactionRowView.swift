import SwiftUI

struct TransactionRowView: View {
    let item: TransactionRowData

    private var iconTint: Color {
        IconRegistry.tintColor(for: item.iconId)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: IconRegistry.symbolName(for: item.iconId))
                .font(.body.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 42, height: 42)
                .background(iconTint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.storeName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.matchedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(item.matchedItems, id: \.self) { matched in
                            Text("• \(matched)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            Text(item.amountFormatted)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

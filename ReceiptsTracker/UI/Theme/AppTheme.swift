import SwiftUI

enum AppTheme {
    /// Native iOS semantic chart palette (adapts automatically to Light, Dark, and Increased Contrast modes)
    static let chartPalette: [Color] = [
        .blue,
        .teal,
        .indigo,
        .orange,
        .pink,
        .purple,
        .green,
        .mint
    ]

    static func chartColor(at index: Int) -> Color {
        chartPalette[abs(index) % chartPalette.count]
    }

    static let groupedBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let tertiaryBackground = Color(.tertiarySystemGroupedBackground)
}

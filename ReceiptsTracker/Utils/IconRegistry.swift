import SwiftUI

enum IconRegistry {
    static let availableSymbols: [String: String] = [
        "shopping_cart": "cart",
        "restaurant": "fork.knife",
        "coffee": "cup.and.saucer",
        "bar": "wineglass",
        "fastfood": "takeoutbag.and.cup.and.straw",
        "bus": "bus",
        "car": "car",
        "gas": "fuelpump",
        "flight": "airplane",
        "gym": "dumbbell",
        "health": "cross.case",
        "pharmacy": "pills",
        "tech": "laptopcomputer",
        "phone": "iphone",
        "home": "house",
        "utilities": "lightbulb",
        "pet": "pawprint",
        "gift": "gift",
        "education": "graduationcap",
        "work": "briefcase"
    ]

    static func symbolName(for iconId: String?) -> String {
        guard let iconId, let symbol = availableSymbols[iconId] else {
            return "receipt"
        }
        return symbol
    }

    static func tintColor(for iconId: String?) -> Color {
        switch iconId {
        case "shopping_cart": return .green
        case "restaurant", "coffee", "bar", "fastfood": return .orange
        case "bus", "car", "gas", "flight": return .blue
        case "tech", "phone": return .indigo
        case "health", "pharmacy", "gym": return .red
        case "utilities", "home": return .yellow
        case "gift", "pet": return .pink
        case "education", "work": return .purple
        default: return .accentColor
        }
    }
}

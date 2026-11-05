import SwiftUI

/// Same preset colors as the iOS daily form (kept private there, so mirrored here).
enum MacDailyPalette {
    static let taskColors = ["#5E81F4", "#FF6B6B", "#4ECDC4", "#FFD93D", "#6C5CE7", "#A8E6CF", "#FF8B94"]

    static func color(hex: String?) -> Color {
        Color(hex: hex ?? taskColors[0])
    }
}

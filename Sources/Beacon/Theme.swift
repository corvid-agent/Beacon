import SwiftUI

enum Theme {
    static let accent = Color(red: 0.4, green: 0.9, blue: 0.6)
    static let background = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let text = Color.white
    static let textSecondary = Color(white: 0.6)
    static let border = Color.white.opacity(0.1)

    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)

    static let windowWidth: CGFloat = 320
    static let cornerRadius: CGFloat = 8
    static let padding: CGFloat = 12
}

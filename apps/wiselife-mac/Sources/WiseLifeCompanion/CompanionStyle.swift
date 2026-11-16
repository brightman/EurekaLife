import SwiftUI

/// Native tokens matching the approved Mac product prototype.
enum Theme {
    static let ink = color(0x262626)
    static let muted = color(0x8c8c8c)
    static let accent = color(0x262626)
    static let blueSoft = color(0xebebeb)
    static let green = color(0x34745e)
    static let line = color(0xf0f0f0)
    static let background = color(0xffffff)
    static let sidebar = color(0xfafafa)
    static let field = color(0xfafafa)
    static let card = Color.white
    static let warning = color(0x916014)
    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct CompanionPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .semibold))
            .foregroundStyle(enabled ? .white : Theme.muted.opacity(0.55))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(enabled ? Theme.accent.opacity(configuration.isPressed ? 0.8 : 1) : Theme.field,
                        in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CompanionSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.accent.opacity(enabled ? 1 : 0.4))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(configuration.isPressed ? Theme.blueSoft : Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
    }
}

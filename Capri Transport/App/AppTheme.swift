import SwiftUI

/// Кольори інтерфейсу (палітра з `AppAppearance` або морська за замовчуванням).
enum AppTheme {
    private static var p: ThemePalette {
        AppAppearance.current?.palette ?? .sea
    }

    static var accent: Color { p.accent }
    static var accentSoft: Color { p.accentSoft }
    static var highlightFill: Color { p.highlightFill }
    static var highlightText: Color { p.highlightText }
    static var cardStroke: Color { p.cardStroke }
    static var shadow: Color { p.shadow }
}

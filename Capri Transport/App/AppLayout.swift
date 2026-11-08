import SwiftUI

/// Адаптація під iPhone (SE → Pro Max) та iPad.
enum AppLayout {
    static let maxContentWidth: CGFloat = 680
    static let minTouch: CGFloat = 44

    static func horizontalPadding(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .regular ? 28 : 16
    }
}

private struct ReadableContentWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppLayout.horizontalPadding(horizontalSizeClass: horizontalSizeClass))
            .frame(maxWidth: horizontalSizeClass == .regular ? AppLayout.maxContentWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Центрує контент на iPad, повна ширина на вузьких iPhone.
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidthModifier())
    }
}

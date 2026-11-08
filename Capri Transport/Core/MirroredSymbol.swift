import SwiftUI

/// SF Symbol з м’яким відображенням униз (дзеркальна іконка).
struct MirroredSymbol: View {
    let systemName: String
    var compact = false
    var font: Font = .body

    var body: some View {
        VStack(spacing: compact ? 0 : 2) {
            Image(systemName: systemName)
                .font(font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)

            Image(systemName: systemName)
                .font(compact ? font : font)
                .scaleEffect(x: 1, y: -1)
                .opacity(compact ? 0.14 : 0.2)
                .foregroundStyle(AppTheme.accent)
                .frame(height: compact ? 10 : 16)
                .clipped()
                .mask(
                    LinearGradient(
                        colors: [.black, .black.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .accessibilityHidden(true)
    }
}

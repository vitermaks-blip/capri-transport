import SwiftUI

enum SightPhotoMotion {
    static func kenBurns(sightId: String, t: TimeInterval, enabled: Bool) -> (drift: CGSize, zoom: CGFloat) {
        guard enabled else { return (.zero, 1) }
        var hasher = Hasher()
        hasher.combine(sightId)
        let seed = Double(abs(hasher.finalize()) % 997) / 997
        let speed = 0.06 + seed * 0.035
        let x = sin(t * speed + seed * 5.8) * 7
        let y = cos(t * speed * 0.9 + seed * 2.9) * 6
        let zoom = 1.07 + CGFloat(sin(t * speed * 0.55 + seed)) * 0.035
        return (CGSize(width: x, height: y), zoom)
    }
}

/// Фото з Assets (`imageName`), з мережі (`imageURL`) або плейсхолдер.
struct SightPhotoView: View {
    let sight: Sight
    var offlineHint = false
    /// Повільний дрейф усередині обрізаної рамки (Ken Burns); лише коли батько передає значення.
    var drift: CGSize = .zero
    var zoom: CGFloat = 1

    var body: some View {
        Group {
            if let name = sight.imageName {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else if let url = sight.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.secondary.opacity(0.12))
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .scaleEffect(zoom, anchor: .center)
        .offset(drift)
        .overlay(alignment: .bottom) {
            if offlineHint, sight.imageURL != nil, sight.imageName == nil {
                Text("📷")
                    .font(.caption2)
                    .padding(4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(6)
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.28), AppTheme.highlightFill],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: sight.icon)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
        }
    }
}

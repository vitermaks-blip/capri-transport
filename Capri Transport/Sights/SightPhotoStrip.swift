import SwiftUI

/// Горизонтальна смуга: прокрутка вручну (без автоматичного marquee) — менше навантаження від TimelineView.
struct SightPhotoStrip: View {
    let sights: [Sight]
    let l: L10n
    var motionTime: TimeInterval = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var cardWidth: CGFloat = 132
    @ScaledMetric(relativeTo: .caption) private var cardHeight: CGFloat = 188

    private var stripHeight: CGFloat { cardHeight + 74 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l("sights.photoStrip"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(l("sights.photoStrip.hint"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)

            if sights.isEmpty {
                Color.clear.frame(height: stripHeight)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    cardRow
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .frame(height: stripHeight)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l("sights.photoStrip"))
    }

    private var cardRow: some View {
        HStack(spacing: 12) {
            ForEach(sights) { sight in
                NavigationLink {
                    SightDetailView(sight: sight, l: l)
                } label: {
                    stripCard(sight: sight)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stripCard(sight: Sight) -> some View {
        let motion = SightPhotoMotion.kenBurns(sightId: sight.id, t: motionTime, enabled: !reduceMotion)
        return VStack(alignment: .leading, spacing: 6) {
            SightPhotoView(sight: sight, drift: motion.drift, zoom: motion.zoom)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }

            Text(sight.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: cardWidth, alignment: .leading)
                .foregroundStyle(.primary)
        }
        .padding(8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(sight.name)
    }
}

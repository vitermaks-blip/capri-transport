import SwiftUI

struct StaleCatalogBanner: View {
    let l: L10n
    var daysOld: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(AppTheme.highlightText)
            VStack(alignment: .leading, spacing: 2) {
                Text(l("data.stale.title"))
                    .font(.subheadline.weight(.semibold))
                Text(l.staleCatalogBody(daysOld: daysOld))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.18))
        .accessibilityElement(children: .combine)
    }
}

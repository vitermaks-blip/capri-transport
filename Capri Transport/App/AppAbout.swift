import SwiftUI

struct DataDisclaimerBanner: View {
    let l: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(l("data.banner.title"), systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.highlightText)
            Text(l("data.banner.body"))
                .font(.caption)
                .foregroundStyle(AppTheme.highlightText.opacity(0.9))
            if let stamp = Catalog.dataUpdatedLabel {
                Text(l("about.updated") + ": \(stamp)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.highlightText.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.cardStroke))
        .accessibilityElement(children: .combine)
    }
}

struct AboutDataView: View {
    let l: L10n
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(l("about.data")) {
                    Text(l("note"))
                        .font(.body)
                    if let stamp = Catalog.dataUpdatedLabel {
                        LabeledContent(l("about.updated"), value: stamp)
                    }
                    LabeledContent(l("about.routes"), value: "\(Catalog.all.count)")
                    if let stamp = SightCatalog.dataUpdated {
                        LabeledContent(l("about.sights.updated"), value: stamp)
                    }
                    LabeledContent(l("about.sights"), value: "\(SightCatalog.all.count)")
                }
                Section(l("about.deeplink")) {
                    Text(l("about.deeplink.hint"))
                        .font(.footnote)
                    if let sample = AppState().deepLinkURL(routeID: "bus-mg-ana") {
                        LabeledContent("capritransport", value: sample.absoluteString)
                            .font(.caption.monospaced())
                    }
                }
                Section(l("about.sources")) {
                    Text(l("about.sources.body"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section(l("about.travel")) {
                    Text(l("travel.guest.note"))
                    Text(l("travel.privacy.keychain"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(l("about.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l("close")) { dismiss() }
                }
            }
        }
    }
}

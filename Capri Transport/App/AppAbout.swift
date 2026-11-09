import SwiftUI

struct DataDisclaimerBanner: View {
    enum Style { case strip, card }

    let l: L10n
    var source: TimetableDataSource = .bundle
    var style: Style = .card

    private var titleKey: String {
        switch source {
        case .network, .cache: "data.banner.title.live"
        case .bundle: "data.banner.title"
        }
    }

    private var sourceHint: String? {
        switch source {
        case .network: l("data.source.network")
        case .cache: l("data.source.cache")
        case .bundle: nil
        }
    }

    var body: some View {
        switch style {
        case .strip:
            strip
        case .card:
            card
        }
    }

    private var strip: some View {
        HStack(alignment: .top, spacing: 8) {
            MirroredSymbol(systemName: "exclamationmark.triangle", compact: true, font: .subheadline)
                .foregroundStyle(AppTheme.highlightText)
            VStack(alignment: .leading, spacing: 2) {
                Text(l(titleKey))
                    .font(.subheadline.weight(.semibold))
                Text(l("data.banner.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                if let hint = sourceHint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let stamp = Catalog.dataUpdatedLabel {
                    Text(l("about.updated") + ": \(stamp)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.highlightText)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppTheme.accentSoft)
        .accessibilityElement(children: .combine)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(l(titleKey), systemImage: "exclamationmark.triangle")
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
                Section(l("about.feed")) {
                    if let url = TimetableFeedURL.url {
                        Text(url.absoluteString)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent(l("about.catalog.source"), value: l.nameShort(Catalog.source))
                    Text(l("about.sync.body"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let days = CatalogFreshness.daysSinceUpdate(Catalog.dataUpdated),
                       CatalogFreshness.isStale(Catalog.dataUpdated) {
                        Text(l.staleCatalogBody(daysOld: days))
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                Section(l("about.deeplink")) {
                    Text(l("about.deeplink.hint"))
                        .font(.footnote)
                    if let sample = AppState().deepLinkURL(routeID: "bus-mg-ana") {
                        LabeledContent("route", value: sample.absoluteString)
                            .font(.caption.monospaced())
                    }
                    if let sight = AppState().deepLinkURL(sightID: "faraglioni") {
                        LabeledContent("sight", value: sight.absoluteString)
                            .font(.caption.monospaced())
                    }
                }
                Section(l("about.widget")) {
                    Text(l("liveActivity.hint"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section(l("about.sources")) {
                    Text(l("about.sources.body"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section(l("about.support")) {
                    Text(l("about.support.body"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = AppSupport.mailURL {
                        Link(destination: url) {
                            Label(AppSupport.email, systemImage: "envelope.fill")
                        }
                        .accessibilityLabel("\(l("about.support.email")), \(AppSupport.email)")
                    }
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

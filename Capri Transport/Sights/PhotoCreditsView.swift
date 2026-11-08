import SwiftUI

struct PhotoCreditsView: View {
    let l: L10n
    @Environment(\.dismiss) private var dismiss

    private var credits: [PhotoCredit] { PhotoCreditsCatalog.all }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(l("sights.credits.intro"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(credits) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(SightCatalog.all.first { $0.id == c.sightId }?.name ?? c.sightId)
                            .font(.headline)
                        LabeledContent(l("sights.credits.license"), value: c.license)
                        LabeledContent(l("sights.credits.artist"), value: c.artist)
                        if c.shareAlike {
                            Label(l("sights.credits.sa"), systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                        }
                        if let note = c.note {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                        if let url = c.pageURL {
                            Link(l("sights.credits.commons"), destination: url)
                                .font(.caption)
                        }
                        if !c.verified {
                            Label(l("sights.credits.unverified"), systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(l("sights.credits.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l("close")) { dismiss() }
                }
            }
        }
    }
}

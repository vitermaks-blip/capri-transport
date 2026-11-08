import SwiftUI
import MapKit

struct RouteMapSheet: View {
    let route: Route
    let departure: Departure
    let l: L10n
    @Environment(\.dismiss) private var dismiss
    @Environment(NetworkMonitor.self) private var network

    private var from: CLLocationCoordinate2D { route.endpoint(route.from) }
    private var to: CLLocationCoordinate2D { route.endpoint(route.to) }

    private var subtitle: String {
        var parts: [String] = []
        if let op = departure.op { parts.append(op) }
        if let k = route.kind, let m = route.durationMin {
            parts.append("\(l(k.rawValue)) · ~\(m) \(l("m"))")
            parts.append("\(l("arrival")) \(Rome.hhmm(departure.minute + m))")
        }
        return parts.joined(separator: " · ")
    }

    private var buyTicketURL: URL? { route.ticketURL(for: departure) }

    private var googleURL: URL? {
        var c = URLComponents(string: "https://www.google.com/maps/dir/")!
        c.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "origin", value: "\(from.latitude),\(from.longitude)"),
            URLQueryItem(name: "destination", value: "\(to.latitude),\(to.longitude)"),
            URLQueryItem(name: "travelmode", value: "transit"),
            URLQueryItem(name: "hl", value: l.lang.rawValue),
        ]
        return c.url
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Map(initialPosition: .rect(Self.rect(route.path))) {
                    Marker(l.place(route.from), coordinate: from).tint(AppTheme.accent)
                    Marker(l.place(route.to), coordinate: to).tint(.secondary)
                    MapPolyline(coordinates: route.path)
                        .stroke(AppTheme.accent.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                                          dash: route.mode == .ships ? [8, 6] : []))
                }
                .mapStyle(.standard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }

                if !network.isOnline {
                    Label(l("offline.maps"), systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    if let googleURL {
                        Link(destination: googleURL) {
                            Label(l("openGM"), systemImage: "map").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button { openAppleMaps() } label: {
                        Label(l("openAM"), systemImage: "apple.logo").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let buyTicketURL {
                    Link(destination: buyTicketURL) {
                        Label(l("buyTicket"), systemImage: "ticket").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                    .disabled(!network.isOnline)

                    Text(l("ticketNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("\(Rome.hhmm(departure.minute)) · \(l.name(route))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(
                        item: RouteShare.departureText(
                            route: route,
                            departure: departure,
                            on: Rome.today,
                            l: l
                        ),
                        subject: Text(l.name(route)),
                        message: Text(Rome.hhmm(departure.minute))
                    ) {
                        Label(l("share.departure"), systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l("close")) { dismiss() }
                }
            }
        }
    }

    private func openAppleMaps() {
        let a = MKMapItem(placemark: MKPlacemark(coordinate: from)); a.name = l.place(route.from)
        let b = MKMapItem(placemark: MKPlacemark(coordinate: to));   b.name = l.place(route.to)
        MKMapItem.openMaps(with: [a, b],
                           launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
    }

    private static func rect(_ cs: [CLLocationCoordinate2D]) -> MKMapRect {
        var r = MKMapRect.null
        for c in cs {
            let p = MKMapPoint(c)
            r = r.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        let pad = max(r.width, r.height) * 0.3 + 4000
        return r.insetBy(dx: -pad, dy: -pad)
    }
}

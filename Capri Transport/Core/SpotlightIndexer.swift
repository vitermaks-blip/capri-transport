import CoreLocation
import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightIndexer {
    private static let domain = "com.taptap.Capri-Transport"

    static func reindex() {
        let routes = Catalog.all
        let sights = SightCatalog.all
        guard !routes.isEmpty || !sights.isEmpty else { return }

        var items: [CSSearchableItem] = []
        items.reserveCapacity(routes.count + sights.count)

        for route in routes {
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = "\(route.from.rawValue) → \(route.to.rawValue)"
            attrs.contentDescription = route.id
            items.append(CSSearchableItem(
                uniqueIdentifier: "route:\(route.id)",
                domainIdentifier: "\(domain).routes",
                attributeSet: attrs
            ))
        }

        for sight in sights {
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = sight.name
            attrs.contentDescription = sight.query
            attrs.latitude = NSNumber(value: sight.coordinate.latitude)
            attrs.longitude = NSNumber(value: sight.coordinate.longitude)
            items.append(CSSearchableItem(
                uniqueIdentifier: "sight:\(sight.id)",
                domainIdentifier: "\(domain).sights",
                attributeSet: attrs
            ))
        }

        CSSearchableIndex.default().indexSearchableItems(items)
    }
}

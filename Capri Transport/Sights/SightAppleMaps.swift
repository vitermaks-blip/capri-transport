import MapKit

enum SightAppleMaps {
    /// Картка місця в Apple Maps (без маршруту).
    static func openPlace(_ sight: Sight, displayName: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: sight.coordinate))
        item.name = displayName
        item.openInMaps()
    }

    /// Марина Grande → пам’ятка (пішки — останній відрізок після кроків у додатку).
    static func openWalkingFromMarina(to sight: Sight, sightName: String, marinaName: String) {
        let start = MKMapItem(placemark: MKPlacemark(coordinate: PlaceID.mg.coordinate))
        start.name = marinaName
        let dest = MKMapItem(placemark: MKPlacemark(coordinate: sight.coordinate))
        dest.name = sightName
        MKMapItem.openMaps(
            with: [start, dest],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        )
    }

    static func openCapriOverview(islandName: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: PlaceID.capri.coordinate))
        item.name = islandName
        item.openInMaps()
    }
}

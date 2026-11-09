# Capri TransportWidget

Widget extension target (home screen + Live Activity UI).

## Xcode

The **`Capri TransportWidget`** target is defined in `Capri Transport.xcodeproj/project.xcproj`. After pull:

1. Open the project in **Xcode 27+**.
2. Select app + widget targets → **Signing & Capabilities** → App Group `group.com.taptap.Capri-Transport`.
3. Build & run the app, star a route, open the schedule tab once to refresh the snapshot.
4. Add **Next departure** widget; Live Activity appears when a route is starred (iOS 16.2+).

Shared types: `Capri Transport/Widget/WidgetDepartureSnapshot.swift`, `DepartureActivityAttributes.swift`.

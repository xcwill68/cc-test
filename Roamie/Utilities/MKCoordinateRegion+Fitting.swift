import MapKit

extension MKCoordinateRegion {
    static func fitting(coordinates: [CLLocationCoordinate2D], padding: Double = 0.2) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
                                      span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30))
        }
        guard coordinates.count > 1 else {
            return MKCoordinateRegion(center: coordinates[0],
                                      span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        }
        let minLat = coordinates.map { $0.latitude }.min()!
        let maxLat = coordinates.map { $0.latitude }.max()!
        let minLon = coordinates.map { $0.longitude }.min()!
        let maxLon = coordinates.map { $0.longitude }.max()!
        let latDelta = max((maxLat - minLat) * (1 + padding), 0.5)
        let lonDelta = max((maxLon - minLon) * (1 + padding), 0.5)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        return MKCoordinateRegion(center: center,
                                  span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}

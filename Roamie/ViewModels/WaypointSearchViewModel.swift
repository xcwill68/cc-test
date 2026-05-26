import Foundation
import MapKit

@MainActor
@Observable
final class WaypointSearchViewModel {
    var queryText: String = ""
    var isLocating: Bool = false
    var errorMessage: String?

    let searchService = SearchService()

    func search(region: MKCoordinateRegion? = nil) {
        searchService.search(query: queryText, region: region)
    }

    func clear() {
        queryText = ""
        searchService.clear()
    }

    func locateAndAdd(nextOrder: Int, completion: @escaping @MainActor (Waypoint) -> Void) {
        isLocating = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let location = try await LocationService.shared.getCurrentLocation()
                let (name, subtitle) = try await LocationService.shared.reverseGeocode(location)
                let wp = Waypoint(order: nextOrder, name: name, subtitle: subtitle,
                                  latitude: location.coordinate.latitude,
                                  longitude: location.coordinate.longitude)
                isLocating = false
                completion(wp)
            } catch {
                isLocating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

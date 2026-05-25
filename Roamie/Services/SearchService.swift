import Foundation
import MapKit

@Observable
final class SearchService {
    var results: [MKMapItem] = []
    var isSearching = false
    var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    func search(query: String, region: MKCoordinateRegion? = nil) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            // Debounce: wait 300ms before firing
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true
            errorMessage = nil
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = .pointOfInterest
                if let region { request.region = region }

                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                if !Task.isCancelled {
                    results = response.mapItems
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    results = []
                }
            }
            isSearching = false
        }
    }

    func clear() {
        searchTask?.cancel()
        results = []
        isSearching = false
        errorMessage = nil
    }

    func makeWaypoint(from mapItem: MKMapItem, order: Int) -> Waypoint {
        let coord = mapItem.placemark.coordinate
        let name = mapItem.name ?? mapItem.placemark.locality ?? "未知"
        let parts = [mapItem.placemark.administrativeArea, mapItem.placemark.countryCode]
            .compactMap { $0 }
        let subtitle = parts.isEmpty ? nil : parts.joined(separator: " · ")
        return Waypoint(order: order, name: name, subtitle: subtitle,
                        latitude: coord.latitude, longitude: coord.longitude)
    }
}

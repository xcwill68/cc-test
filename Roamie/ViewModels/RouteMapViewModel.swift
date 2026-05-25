import Foundation
import MapKit
import CoreLocation

@Observable
final class RouteMapViewModel {
    var region: MKCoordinateRegion = .init()
    var isRecording: Bool = false
    var errorMessage: String?

    func fitRegion(to waypoints: [Waypoint]) {
        guard !waypoints.isEmpty else { return }
        region = .fitting(coordinates: waypoints.map { $0.coordinate }, padding: 0.3)
    }

    func toggleRecording() {
        if isRecording {
            Task {
                let locations = await LocationService.shared.stopRecording()
                await MainActor.run { isRecording = false }
                _ = locations  // Future: sample track into waypoints
            }
        } else {
            Task {
                await LocationService.shared.requestPermission()
                await LocationService.shared.startRecording()
                await MainActor.run { isRecording = true }
            }
        }
    }
}

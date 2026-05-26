import SwiftUI
import SwiftData
import PhotosUI

@MainActor
@Observable
final class TripEditorViewModel {
    var isShowingSearch: Bool = false
    var isShowingMapPreview: Bool = false
    var isShowingAnimation: Bool = false
    var isPickingPhotos: Bool = false
    var selectedWaypointForPhotos: Waypoint?
    var photoPickerItems: [PhotosPickerItem] = []
    var errorMessage: String?

    func addWaypoint(_ waypoint: Waypoint, to trip: Trip, context: ModelContext) {
        waypoint.order = trip.waypoints.count
        waypoint.trip = trip
        trip.waypoints.append(waypoint)
        trip.modifiedAt = Date()
        try? context.save()
    }

    func moveWaypoints(in trip: Trip, from source: IndexSet, to destination: Int, context: ModelContext) {
        var ordered = trip.orderedWaypoints
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, wp) in ordered.enumerated() { wp.order = i }
        trip.modifiedAt = Date()
        try? context.save()
    }

    func deleteWaypoint(_ waypoint: Waypoint, from trip: Trip, context: ModelContext) {
        PhotoStorageService.shared.deleteAll(fileNames: waypoint.photoFileNames)
        trip.waypoints.removeAll { $0.id == waypoint.id }
        for (i, wp) in trip.orderedWaypoints.enumerated() { wp.order = i }
        context.delete(waypoint)
        trip.modifiedAt = Date()
        try? context.save()
    }

    func processPickedPhotos(for waypoint: Waypoint, context: ModelContext) {
        let items = photoPickerItems
        photoPickerItems = []
        guard !items.isEmpty else { return }
        let waypointID = waypoint.id
        // Task inherits @MainActor isolation — safe to capture SwiftData types
        Task { @MainActor in
            let images = await PhotoStorageService.shared.process(pickerItems: items)
            var newFileNames: [String] = []
            for image in images {
                if let fileName = try? PhotoStorageService.shared.save(image: image, for: waypointID) {
                    newFileNames.append(fileName)
                }
            }
            waypoint.photoFileNames.append(contentsOf: newFileNames)
            try? context.save()
        }
    }

    func removePhoto(fileName: String, from waypoint: Waypoint, context: ModelContext) {
        PhotoStorageService.shared.delete(fileName: fileName)
        waypoint.photoFileNames.removeAll { $0 == fileName }
        try? context.save()
    }

    func addLocationWaypoint(to trip: Trip, context: ModelContext) {
        Task { @MainActor in
            do {
                let location = try await LocationService.shared.getCurrentLocation()
                let (name, subtitle) = try await LocationService.shared.reverseGeocode(location)
                let waypoint = Waypoint(
                    order: trip.waypoints.count,
                    name: name,
                    subtitle: subtitle,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                addWaypoint(waypoint, to: trip, context: context)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

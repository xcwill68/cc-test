import SwiftUI
import SwiftData

@Observable
final class TripListViewModel {
    var searchText: String = ""
    var isCreatingNewTrip: Bool = false

    func delete(_ trip: Trip, from context: ModelContext) {
        // Clean up photos from disk before deleting
        for wp in trip.waypoints {
            PhotoStorageService.shared.deleteAll(fileNames: wp.photoFileNames)
        }
        context.delete(trip)
    }

    func duplicate(_ trip: Trip, into context: ModelContext) {
        let copy = Trip(title: "\(trip.title) 副本",
                        mapStyle: trip.mapStyle,
                        characterAssetName: trip.characterAssetName)
        for wp in trip.orderedWaypoints {
            let newWp = Waypoint(order: wp.order, name: wp.name, subtitle: wp.subtitle,
                                 latitude: wp.latitude, longitude: wp.longitude)
            newWp.arrivalDate = wp.arrivalDate
            newWp.departureDate = wp.departureDate
            newWp.note = wp.note
            // Photos are not duplicated to avoid storage bloat
            copy.waypoints.append(newWp)
        }
        context.insert(copy)
    }
}

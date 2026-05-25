import Foundation
import CoreLocation
import SwiftData

@Model
final class Waypoint {
    var id: UUID
    var order: Int
    var name: String
    var subtitle: String?
    var latitude: Double
    var longitude: Double
    var arrivalDate: Date?
    var departureDate: Date?
    var note: String?
    var photoFileNames: [String]
    var trip: Trip?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasPhotos: Bool { !photoFileNames.isEmpty }

    init(
        order: Int,
        name: String,
        subtitle: String? = nil,
        latitude: Double,
        longitude: Double
    ) {
        self.id = UUID()
        self.order = order
        self.name = name
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.photoFileNames = []
    }
}

import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var mapStyleRaw: Int
    var characterAssetName: String

    @Relationship(deleteRule: .cascade, inverse: \Waypoint.trip)
    var waypoints: [Waypoint]

    var mapStyle: PixelMapStyle {
        get { PixelMapStyle(rawValue: mapStyleRaw) ?? .terrain }
        set { mapStyleRaw = newValue.rawValue }
    }

    var orderedWaypoints: [Waypoint] {
        waypoints.sorted { $0.order < $1.order }
    }

    var hasAnyPhotos: Bool {
        waypoints.contains { $0.hasPhotos }
    }

    init(
        title: String = "",
        mapStyle: PixelMapStyle = .terrain,
        characterAssetName: String = CharacterAsset.carFlag.assetName
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.mapStyleRaw = mapStyle.rawValue
        self.characterAssetName = characterAssetName
        self.waypoints = []
    }
}

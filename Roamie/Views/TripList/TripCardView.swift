import SwiftUI

struct TripCardView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.characterAssetName.characterEmoji)
                    .font(.title2)
                Text(trip.title.isEmpty ? "未命名旅程" : trip.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                mapStyleBadge
            }
            if !trip.orderedWaypoints.isEmpty {
                Text(routeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                Label("\(trip.waypoints.count) 个城市",
                      systemImage: "mappin.and.ellipse")
                if trip.hasAnyPhotos {
                    Label("含打卡照",
                          systemImage: "photo.stack")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var mapStyleBadge: some View {
        Text(trip.mapStyle.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }

    private var routeSummary: String {
        trip.orderedWaypoints.map { $0.name }.joined(separator: " → ")
    }
}

private extension String {
    var characterEmoji: String {
        switch self {
        case "car_flag":  return "🚗"
        case "plane":     return "✈️"
        case "train":     return "🚂"
        case "traveler":  return "🧍"
        default:          return "📍"
        }
    }
}

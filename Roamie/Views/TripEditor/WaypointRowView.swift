import SwiftUI

struct WaypointRowView: View {
    let waypoint: Waypoint
    let onAddPhotos: () -> Void
    let onRemovePhoto: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(waypoint.name)
                        .font(.headline)
                    if let sub = waypoint.subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: onAddPhotos) {
                    Image(systemName: waypoint.hasPhotos ? "photo.stack" : "photo.badge.plus")
                        .foregroundStyle(waypoint.hasPhotos ? .orange : .secondary)
                }
            }

            if waypoint.hasPhotos {
                PhotoThumbnailStrip(waypoint: waypoint, onRemove: onRemovePhoto)
            }
        }
        .padding(.vertical, 4)
    }
}

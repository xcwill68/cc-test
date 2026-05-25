import SwiftUI

struct PhotoThumbnailStrip: View {
    let waypoint: Waypoint
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(waypoint.photoFileNames, id: \.self) { fileName in
                    ThumbnailCell(fileName: fileName, onRemove: { onRemove(fileName) })
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct ThumbnailCell: View {
    let fileName: String
    let onRemove: () -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.2)
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black)
                    .font(.system(size: 18))
            }
            .offset(x: 6, y: -6)
        }
        .task {
            image = PhotoStorageService.shared.loadThumbnail(
                fileName: fileName,
                size: CGSize(width: 144, height: 144)
            )
        }
    }
}

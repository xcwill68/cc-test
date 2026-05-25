import SwiftUI
import MapKit

struct RouteMapView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RouteMapViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Map(initialPosition: .region(viewModel.region)) {
                    // Route polyline
                    if trip.orderedWaypoints.count >= 2 {
                        let coords = trip.orderedWaypoints.map { $0.coordinate }
                        MapPolyline(coordinates: coords)
                            .stroke(Color(uiColor: trip.mapStyle.routeColor),
                                    style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                    }
                    // City annotations
                    ForEach(trip.orderedWaypoints) { wp in
                        Annotation(wp.name, coordinate: wp.coordinate) {
                            CityPinView(name: wp.name,
                                        dotColor: Color(uiColor: trip.mapStyle.dotColor),
                                        hasPhotos: wp.hasPhotos)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onAppear { viewModel.fitRegion(to: trip.orderedWaypoints) }

                // Pixel route overlay drawn via Canvas
                PixelRouteOverlay(trip: trip, region: viewModel.region)
                    .allowsHitTesting(false)
            }
            .navigationTitle(trip.title.isEmpty ? "路线预览" : trip.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct CityPinView: View {
    let name: String
    let dotColor: Color
    let hasPhotos: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(dotColor)
                    .frame(width: 20, height: 20)
                if hasPhotos {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                }
            }
            .shadow(radius: 3)
            Text(name)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
        }
    }
}

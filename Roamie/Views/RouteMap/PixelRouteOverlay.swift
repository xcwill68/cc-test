import SwiftUI
import MapKit

// A SwiftUI Canvas-based pixel route overlay drawn on top of the map.
// Converts waypoint coordinates to view coordinates using the current region.
struct PixelRouteOverlay: View {
    let trip: Trip
    let region: MKCoordinateRegion

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let points = trip.orderedWaypoints.map { wp in
                    coordinateToPoint(wp.coordinate, in: region, size: size)
                }
                guard points.count >= 2 else { return }

                // Draw dashed pixel route line
                var path = Path()
                path.move(to: points[0])
                for pt in points.dropFirst() { path.addLine(to: pt) }

                ctx.stroke(path, with: .color(Color(uiColor: trip.mapStyle.routeColor)),
                           style: StrokeStyle(lineWidth: 3,
                                              lineCap: .round,
                                              lineJoin: .round,
                                              dash: [8, 5]))

                // Draw city dots
                for pt in points {
                    let rect = CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10)
                    ctx.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(.white))
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color(uiColor: trip.mapStyle.dotColor)))
                }
            }
        }
    }

    private func coordinateToPoint(_ coord: CLLocationCoordinate2D,
                                   in region: MKCoordinateRegion,
                                   size: CGSize) -> CGPoint {
        let latDelta = region.span.latitudeDelta
        let lonDelta = region.span.longitudeDelta
        let x = (coord.longitude - (region.center.longitude - lonDelta / 2)) / lonDelta * size.width
        let y = ((region.center.latitude + latDelta / 2) - coord.latitude) / latDelta * size.height
        return CGPoint(x: x, y: y)
    }
}

import Foundation
import CoreGraphics
import UIKit
import MapKit

// MARK: - Path Parameterization

struct PathPoint {
    let position: CGPoint
    let tangentAngle: CGFloat  // radians; 0 = right
    let arcLength: CGFloat
}

func buildArcLengthTable(from points: [CGPoint], stepSize: CGFloat = 1.0) -> [PathPoint] {
    guard points.count >= 2 else { return [] }
    var table: [PathPoint] = []
    var cumLength: CGFloat = 0

    for i in 0..<(points.count - 1) {
        let p0 = points[i]
        let p1 = points[i + 1]
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        let segLength = sqrt(dx * dx + dy * dy)
        let angle = atan2(dy, dx)
        var t: CGFloat = 0
        while t <= segLength {
            let x = p0.x + (dx / segLength) * t
            let y = p0.y + (dy / segLength) * t
            table.append(PathPoint(position: CGPoint(x: x, y: y),
                                   tangentAngle: angle,
                                   arcLength: cumLength + t))
            t += stepSize
        }
        cumLength += segLength
    }
    // Add final point
    if let last = points.last {
        let prev = points[points.count - 2]
        let angle = atan2(last.y - prev.y, last.x - prev.x)
        table.append(PathPoint(position: last, tangentAngle: angle, arcLength: cumLength))
    }
    return table
}

func interpolate(table: [PathPoint], at arcLength: CGFloat) -> PathPoint? {
    guard !table.isEmpty else { return nil }
    if arcLength <= table[0].arcLength { return table[0] }
    if arcLength >= table.last!.arcLength { return table.last }
    // Binary search
    var lo = 0, hi = table.count - 1
    while lo < hi - 1 {
        let mid = (lo + hi) / 2
        if table[mid].arcLength <= arcLength { lo = mid } else { hi = mid }
    }
    let t = (arcLength - table[lo].arcLength) / max(table[hi].arcLength - table[lo].arcLength, 1e-6)
    let x = table[lo].position.x + t * (table[hi].position.x - table[lo].position.x)
    let y = table[lo].position.y + t * (table[hi].position.y - table[lo].position.y)
    return PathPoint(position: CGPoint(x: x, y: y),
                     tangentAngle: table[lo].tangentAngle,
                     arcLength: arcLength)
}

// MARK: - Render Config

struct AnimationConfig {
    // GIF mode: 480×480, 12fps, 6 seconds → 72 frames
    static let gif = AnimationConfig(outputSize: CGSize(width: 480, height: 480),
                                     fps: 12, durationSeconds: 6.0, includePhotos: false)
    // Video mode: 720×720, 30fps, dynamic duration
    static func video(durationSeconds: Double) -> AnimationConfig {
        AnimationConfig(outputSize: CGSize(width: 720, height: 720),
                        fps: 30, durationSeconds: durationSeconds, includePhotos: true)
    }

    let outputSize: CGSize
    let fps: Int
    let durationSeconds: Double
    let includePhotos: Bool

    var totalFrames: Int { Int(durationSeconds * Double(fps)) }
}

// MARK: - Render Service

final class AnimationRenderService {
    static let shared = AnimationRenderService()

    // Renders all frames and reports progress via the handler.
    // The handler is called on a background thread.
    func renderFrames(
        trip: Trip,
        mapImage: CGImage,
        snapshot: MKMapSnapshotter.Snapshot?,
        config: AnimationConfig,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [CGImage] {
        let waypoints = trip.orderedWaypoints
        guard waypoints.count >= 2 else { throw RenderError.notEnoughWaypoints }

        // Project waypoint coordinates → pixel points on the map image.
        // When snapshot is nil (offline fallback) use manual lat/lon projection.
        let region = MKCoordinateRegion.fitting(coordinates: waypoints.map { $0.coordinate }, padding: 0.15)
        let captureSize = trip.mapStyle.snapshotCaptureSize
        let pixelPoints = waypoints.map { wp -> CGPoint in
            if let snapshot { return snapshot.point(for: wp.coordinate) }
            return projectCoordinate(wp.coordinate, region: region, size: captureSize)
        }

        // Scale pixel points from snapshotCaptureSize → outputSize
        let scaleX = config.outputSize.width / CGFloat(mapImage.width)
        let scaleY = config.outputSize.height / CGFloat(mapImage.height)
        let scaledPoints = pixelPoints.map { CGPoint(x: $0.x * scaleX, y: $0.y * scaleY) }

        let arcTable = buildArcLengthTable(from: scaledPoints)
        guard let totalLength = arcTable.last?.arcLength, totalLength > 0 else {
            throw RenderError.emptyPath
        }

        let style = trip.mapStyle
        let character = CharacterAsset(rawValue: trip.characterAssetName) ?? .carFlag
        let spriteSheet = SpriteSheet(assetName: character.assetName,
                                      frameCount: character.frameCount,
                                      frameSize: character.spriteSize)

        // Build photo schedule for video mode
        let photoSchedule: [PhotoEvent] = config.includePhotos
            ? buildPhotoSchedule(waypoints: waypoints,
                                 arcTable: arcTable,
                                 totalLength: totalLength,
                                 config: config)
            : []

        var frames: [CGImage] = []
        let travelFrames = config.totalFrames

        for frameIndex in 0..<travelFrames {
            let t = Double(frameIndex) / Double(max(travelFrames - 1, 1))
            let currentArc = CGFloat(t) * totalLength
            let pathPoint = interpolate(table: arcTable, at: currentArc)

            let frame = try renderFrame(
                mapImage: mapImage,
                scaledWaypointPoints: scaledPoints,
                waypoints: waypoints,
                arcTable: arcTable,
                currentArc: currentArc,
                pathPoint: pathPoint,
                spriteSheet: spriteSheet,
                spriteFrame: (frameIndex / 3) % character.frameCount,
                style: style,
                config: config,
                photoSchedule: photoSchedule,
                frameIndex: frameIndex
            )
            frames.append(frame)

            if frameIndex % 10 == 0 {
                progressHandler(Double(frameIndex) / Double(travelFrames))
            }
        }

        progressHandler(1.0)
        return frames
    }

    // MARK: - Single Frame

    private func renderFrame(
        mapImage: CGImage,
        scaledWaypointPoints: [CGPoint],
        waypoints: [Waypoint],
        arcTable: [PathPoint],
        currentArc: CGFloat,
        pathPoint: PathPoint?,
        spriteSheet: SpriteSheet,
        spriteFrame: Int,
        style: PixelMapStyle,
        config: AnimationConfig,
        photoSchedule: [PhotoEvent],
        frameIndex: Int
    ) throws -> CGImage {
        let size = config.outputSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            cgCtx.interpolationQuality = .none  // Preserve pixel art sharpness

            // Layer 1: Pixel map background
            cgCtx.draw(mapImage, in: CGRect(origin: .zero, size: size))

            // Layer 2: Drawn route path up to currentArc
            drawRoutePath(cgCtx, arcTable: arcTable, upToArc: currentArc, style: style)

            // Layer 3: City dots and labels for reached waypoints
            let totalArc = arcTable.last?.arcLength ?? 1
            for (i, point) in scaledWaypointPoints.enumerated() {
                // Evenly distribute waypoint arc positions along the path
                let waypointArc = CGFloat(i) / CGFloat(max(scaledWaypointPoints.count - 1, 1)) * totalArc
                let reached = currentArc >= waypointArc || i == 0
                drawCityDot(cgCtx, at: point, name: waypoints[i].name,
                            reached: reached, style: style)
            }

            // Layer 4: Character sprite at current position
            if let pp = pathPoint, let sprite = spriteSheet.frame(spriteFrame) {
                drawCharacter(cgCtx, sprite: sprite, at: pp.position,
                              angle: pp.tangentAngle, size: config.outputSize)
            }

            // Layer 5: Photo overlay for video mode
            if let event = photoSchedule.first(where: {
                frameIndex >= $0.startFrame && frameIndex < $0.endFrame
            }) {
                let localFrame = frameIndex - event.startFrame
                let totalDuration = event.endFrame - event.startFrame
                drawPhotoOverlay(cgCtx, event: event, localFrame: localFrame,
                                 totalDuration: totalDuration, canvasSize: size)
            }
        }
        guard let cgImage = uiImage.cgImage else { throw RenderError.frameCreationFailed }
        return cgImage
    }

    // MARK: - Drawing helpers

    private func drawRoutePath(_ ctx: CGContext, arcTable: [PathPoint],
                               upToArc: CGFloat, style: PixelMapStyle) {
        guard arcTable.count >= 2 else { return }
        let path = CGMutablePath()
        var started = false
        for point in arcTable {
            if point.arcLength > upToArc { break }
            if !started {
                path.move(to: point.position)
                started = true
            } else {
                path.addLine(to: point.position)
            }
        }
        ctx.setStrokeColor(style.routeColor.cgColor)
        ctx.setLineWidth(4.0)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineDash(phase: 0, lengths: [12, 6])
        ctx.addPath(path)
        ctx.strokePath()
    }

    private func drawCityDot(_ ctx: CGContext, at point: CGPoint,
                              name: String, reached: Bool, style: PixelMapStyle) {
        let radius: CGFloat = reached ? 6 : 4
        let dotRect = CGRect(x: point.x - radius, y: point.y - radius,
                             width: radius * 2, height: radius * 2)
        // Outer white ring
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillEllipse(in: dotRect.insetBy(dx: -2, dy: -2))
        // Coloured fill
        ctx.setFillColor((reached ? style.dotColor : UIColor.gray).cgColor)
        ctx.fillEllipse(in: dotRect)

        guard reached else { return }
        // City label (pixel-friendly monospaced font)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]
        let str = name as NSString
        let strSize = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: point.x - strSize.width / 2,
                             y: point.y + radius + 3), withAttributes: attrs)
    }

    private func drawCharacter(_ ctx: CGContext, sprite: CGImage, at position: CGPoint,
                               angle: CGFloat, size: CGSize) {
        let spriteW: CGFloat = 32
        let spriteH: CGFloat = 32
        ctx.saveGState()
        ctx.translateBy(x: position.x, y: position.y)
        // Flip horizontally if moving left
        if angle > .pi / 2 || angle < -.pi / 2 {
            ctx.scaleBy(x: -1, y: 1)
        }
        ctx.translateBy(x: -spriteW / 2, y: -spriteH / 2)
        ctx.draw(sprite, in: CGRect(x: 0, y: 0, width: spriteW, height: spriteH))
        ctx.restoreGState()
    }

    private func drawPhotoOverlay(_ ctx: CGContext, event: PhotoEvent,
                                  localFrame: Int, totalDuration: Int, canvasSize: CGSize) {
        guard let image = PhotoStorageService.shared.load(fileName: event.fileName) else { return }

        let fadeDuration = 15  // frames for fade in/out
        var alpha: CGFloat = 1.0
        if localFrame < fadeDuration {
            alpha = CGFloat(localFrame) / CGFloat(fadeDuration)
        } else if localFrame > totalDuration - fadeDuration {
            alpha = CGFloat(totalDuration - localFrame) / CGFloat(fadeDuration)
        }

        let margin: CGFloat = 40
        let maxWidth = canvasSize.width - margin * 2
        let maxHeight = canvasSize.height * 0.55
        let photoAspect = image.size.width / image.size.height
        var photoWidth = maxWidth
        var photoHeight = photoWidth / photoAspect
        if photoHeight > maxHeight {
            photoHeight = maxHeight
            photoWidth = photoHeight * photoAspect
        }
        let photoX = (canvasSize.width - photoWidth) / 2
        // Drop-in effect: frame offset from top
        let dropProgress = min(1.0, CGFloat(localFrame) / CGFloat(fadeDuration))
        let dropY = -photoHeight + dropProgress * (canvasSize.height * 0.15 + photoHeight)
        let photoRect = CGRect(x: photoX, y: dropY, width: photoWidth, height: photoHeight)

        // White polaroid frame
        let frameInset: CGFloat = 6
        let frameRect = photoRect.insetBy(dx: -frameInset, dy: -frameInset)
        ctx.setAlpha(alpha)
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.setShadow(offset: CGSize(width: 2, height: 4), blur: 8,
                      color: UIColor.black.withAlphaComponent(0.5).cgColor)
        ctx.fill(frameRect)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        guard let cgPhoto = image.cgImage else { return }
        ctx.draw(cgPhoto, in: photoRect)
        ctx.setAlpha(1.0)
    }

    // MARK: - Photo schedule builder

    private func buildPhotoSchedule(waypoints: [Waypoint],
                                    arcTable: [PathPoint],
                                    totalLength: CGFloat,
                                    config: AnimationConfig) -> [PhotoEvent] {
        var events: [PhotoEvent] = []
        // Evenly distribute waypoint positions across the travel frame count
        let waypointsWithPhotos = waypoints.enumerated().filter { $0.element.hasPhotos }
        for (waypointIndex, waypoint) in waypointsWithPhotos {
            let arrivalT = Double(waypointIndex) / Double(max(waypoints.count - 1, 1))
            let arrivalFrame = Int(arrivalT * Double(config.totalFrames))
            let photoHoldFrames = config.fps * 2  // 2 seconds per photo
            for (photoIndex, fileName) in waypoint.photoFileNames.enumerated() {
                let start = arrivalFrame + photoIndex * (photoHoldFrames + 15)
                let end = start + photoHoldFrames
                events.append(PhotoEvent(fileName: fileName, startFrame: start, endFrame: min(end, config.totalFrames)))
            }
        }
        return events
    }

    enum RenderError: LocalizedError {
        case notEnoughWaypoints, emptyPath, frameCreationFailed
        var errorDescription: String? {
            switch self {
            case .notEnoughWaypoints: return "至少需要两个城市才能生成动图"
            case .emptyPath:          return "路径计算失败"
            case .frameCreationFailed: return "帧渲染失败"
            }
        }
    }
}

// MARK: - Supporting Types

struct PhotoEvent {
    let fileName: String
    let startFrame: Int
    let endFrame: Int
}

// Manual coordinate → pixel projection used when MKMapSnapshot is unavailable
private func projectCoordinate(_ coord: CLLocationCoordinate2D,
                                region: MKCoordinateRegion,
                                size: CGSize) -> CGPoint {
    let x = (coord.longitude - (region.center.longitude - region.span.longitudeDelta / 2))
             / region.span.longitudeDelta * size.width
    let y = ((region.center.latitude + region.span.latitudeDelta / 2) - coord.latitude)
             / region.span.latitudeDelta * size.height
    return CGPoint(x: max(0, min(size.width, x)), y: max(0, min(size.height, y)))
}

final class SpriteSheet {
    let assetName: String
    let frameCount: Int
    let frameSize: CGSize
    private let sheet: CGImage?

    init(assetName: String, frameCount: Int, frameSize: CGSize) {
        self.assetName = assetName
        self.frameCount = frameCount
        self.frameSize = frameSize
        self.sheet = UIImage(named: assetName)?.cgImage
    }

    func frame(_ index: Int) -> CGImage? {
        guard let sheet else { return nil }
        let frameW = Int(frameSize.width)
        let frameH = Int(frameSize.height)
        let cropRect = CGRect(x: index * frameW, y: 0, width: frameW, height: frameH)
        return sheet.cropping(to: cropRect)
    }
}

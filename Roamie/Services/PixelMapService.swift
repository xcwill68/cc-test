import Foundation
import MapKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class PixelMapService {
    static let shared = PixelMapService()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Returns a pixelated map CGImage sized to style.outputSize.
    // The snapshot is taken at snapshotCaptureSize then upscaled with nearest-neighbour
    // to produce true pixel-art blocks.
    func pixelatedMapImage(
        region: MKCoordinateRegion,
        style: PixelMapStyle
    ) async throws -> (image: CGImage, snapshot: MKMapSnapshot) {
        let snapshot = try await captureSnapshot(region: region, style: style)
        let cgImage = try applyPixelEffect(to: snapshot.image, style: style)
        return (cgImage, snapshot)
    }

    // MARK: - Snapshot

    private func captureSnapshot(
        region: MKCoordinateRegion,
        style: PixelMapStyle
    ) async throws -> MKMapSnapshot {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = style.snapshotCaptureSize
        options.mapType = .standard
        options.showsBuildings = false
        // Apply map config via mapConfiguration
        let config = style.mapConfiguration
        options.preferredConfiguration = config

        let snapshotter = MKMapSnapshotter(options: options)
        return try await snapshotter.start()
    }

    // MARK: - Pixel art effect pipeline

    func applyPixelEffect(to image: UIImage, style: PixelMapStyle) throws -> CGImage {
        guard var ciImage = CIImage(image: image) else { throw PixelMapError.ciImageCreationFailed }

        // Step 1: Upscale with nearest-neighbour interpolation for pixel art look
        let scaleX = style.outputSize.width / style.snapshotCaptureSize.width
        let scaleY = style.outputSize.height / style.snapshotCaptureSize.height
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY),
                                              highQualityDownsample: false)
        ciImage = scaledImage

        // Step 2: Posterize (reduce colour depth, game-like palette)
        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = ciImage
        posterize.levels = style.posterizeLevels
        ciImage = posterize.outputImage ?? ciImage

        // Step 3: Slight saturation boost to make colours pop on pixel art
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = 1.4
        colorControls.brightness = 0.0
        colorControls.contrast = 1.1
        ciImage = colorControls.outputImage ?? ciImage

        guard let result = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw PixelMapError.renderFailed
        }
        return result
    }

    enum PixelMapError: LocalizedError {
        case ciImageCreationFailed, renderFailed
        var errorDescription: String? {
            switch self {
            case .ciImageCreationFailed: return "无法处理地图图像"
            case .renderFailed:         return "像素渲染失败"
            }
        }
    }
}

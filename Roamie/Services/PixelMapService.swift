import Foundation
import MapKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

final class PixelMapService {
    static let shared = PixelMapService()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func pixelatedMapImage(
        region: MKCoordinateRegion,
        style: PixelMapStyle
    ) async throws -> (image: CGImage, snapshot: MKMapSnapshotter.Snapshot?) {
        // Try snapshot up to 3 times (MKErrorLoadingThrottled is transient)
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let snapshot = try await captureSnapshot(region: region, style: style)
                let cgImage = try applyPixelEffect(to: snapshot.image, style: style)
                return (cgImage, snapshot)
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(for: .seconds(Double(attempt + 1)))
                }
            }
        }
        // All retries failed — use a generated fallback background
        let fallback = makeFallbackImage(style: style, region: region)
        return (fallback, nil)
    }

    // MARK: - Snapshot

    private func captureSnapshot(
        region: MKCoordinateRegion,
        style: PixelMapStyle
    ) async throws -> MKMapSnapshotter.Snapshot {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = style.snapshotCaptureSize
        options.mapType = .standard
        options.showsBuildings = false
        options.preferredConfiguration = style.mapConfiguration
        return try await MKMapSnapshotter(options: options).start()
    }

    // MARK: - Pixel art effect pipeline

    func applyPixelEffect(to image: UIImage, style: PixelMapStyle) throws -> CGImage {
        guard var ciImage = CIImage(image: image) else { throw PixelMapError.ciImageCreationFailed }

        let scaleX = style.outputSize.width / style.snapshotCaptureSize.width
        let scaleY = style.outputSize.height / style.snapshotCaptureSize.height
        ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY),
                                      highQualityDownsample: false)

        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = ciImage
        posterize.levels = style.posterizeLevels
        ciImage = posterize.outputImage ?? ciImage

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

    // MARK: - Fallback background (when network snapshot fails)

    private func makeFallbackImage(style: PixelMapStyle, region: MKCoordinateRegion) -> CGImage {
        let size = style.outputSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // Pixel-grid background
            let bg = style.backgroundColor
            cgCtx.setFillColor(bg.cgColor)
            cgCtx.fill(CGRect(origin: .zero, size: size))

            // Draw a simple pixel grid to give map feel
            let gridSize: CGFloat = 18
            cgCtx.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
            cgCtx.setLineWidth(1)
            var x: CGFloat = 0
            while x <= size.width { cgCtx.move(to: CGPoint(x: x, y: 0)); cgCtx.addLine(to: CGPoint(x: x, y: size.height)); x += gridSize }
            var y: CGFloat = 0
            while y <= size.height { cgCtx.move(to: CGPoint(x: 0, y: y)); cgCtx.addLine(to: CGPoint(x: size.width, y: y)); y += gridSize }
            cgCtx.strokePath()

            // Subtle "offline" label
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.2)
            ]
            ("MAP OFFLINE" as NSString).draw(
                at: CGPoint(x: size.width / 2 - 38, y: size.height / 2 - 8),
                withAttributes: attrs
            )
        }
        return uiImage.cgImage!
    }

    enum PixelMapError: LocalizedError {
        case ciImageCreationFailed, renderFailed
        var errorDescription: String? {
            switch self {
            case .ciImageCreationFailed: return "无法处理地图图像"
            case .renderFailed:          return "像素渲染失败"
            }
        }
    }
}

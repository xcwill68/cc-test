import Foundation
import CoreGraphics
import MapKit

@Observable
final class AnimationPreviewViewModel {
    var frames: [CGImage] = []
    var currentFrameIndex: Int = 0
    var renderProgress: Double = 0
    var isRendering: Bool = false
    var isExporting: Bool = false
    var errorMessage: String?
    var gifURL: URL?
    var videoURL: URL?

    private var renderTask: Task<Void, Never>?

    func startRender(trip: Trip, mode: ExportMode) {
        renderTask?.cancel()
        frames = []
        renderProgress = 0
        isRendering = true
        errorMessage = nil

        renderTask = Task {
            do {
                let waypoints = trip.orderedWaypoints
                guard waypoints.count >= 2 else { throw AnimationRenderService.RenderError.notEnoughWaypoints }

                // Build region fitting all waypoints
                let coords = waypoints.map { $0.coordinate }
                let region = MKCoordinateRegion.fitting(coordinates: coords, padding: 0.25)

                let config: AnimationConfig = mode == .gif ? .gif : .video(durationSeconds: videoDuration(for: trip))

                // Capture pixel map
                let (mapImage, snapshot) = try await PixelMapService.shared.pixelatedMapImage(
                    region: region, style: trip.mapStyle
                )

                // Render frames
                let rendered = try await AnimationRenderService.shared.renderFrames(
                    trip: trip,
                    mapImage: mapImage,
                    snapshot: snapshot,
                    config: config
                ) { [weak self] progress in
                    Task { @MainActor in self?.renderProgress = progress }
                }

                await MainActor.run {
                    self.frames = rendered
                    self.isRendering = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRendering = false
                }
            }
        }
    }

    func exportGIF() {
        guard !frames.isEmpty else { return }
        isExporting = true
        Task {
            do {
                let url = try await GIFExportService.shared.export(frames: frames, fps: 12)
                await MainActor.run {
                    gifURL = url
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    func exportVideo() {
        guard !frames.isEmpty else { return }
        isExporting = true
        Task {
            do {
                let url = try await VideoExportService.shared.export(
                    frames: frames, fps: 30, size: CGSize(width: 720, height: 720)
                )
                await MainActor.run {
                    videoURL = url
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    func cancelRender() {
        renderTask?.cancel()
        isRendering = false
    }

    private func videoDuration(for trip: Trip) -> Double {
        let travelSeconds = 6.0
        let photoSeconds = trip.orderedWaypoints.reduce(0.0) {
            $0 + Double($1.photoFileNames.count) * 2.5
        }
        return travelSeconds + photoSeconds
    }
}

enum ExportMode {
    case gif
    case video
}

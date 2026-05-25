import Foundation
import AVFoundation
import CoreGraphics
import UIKit

final class VideoExportService {
    static let shared = VideoExportService()

    func export(frames: [CGImage], fps: Int, size: CGSize) async throws -> URL {
        let outputURL = temporaryURL(extension: "mp4")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        for (index, cgImage) in frames.enumerated() {
            while !input.isReadyForMoreMediaData { await Task.yield() }
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            if let buffer = cgImage.toPixelBuffer(size: size) {
                adaptor.append(buffer, withPresentationTime: presentationTime)
            }
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? ExportError.writeFailed
        }
        return outputURL
    }

    private func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("roamie_\(UUID().uuidString).\(ext)")
    }

    enum ExportError: LocalizedError {
        case writeFailed
        var errorDescription: String? { "视频写入失败" }
    }
}

private extension CGImage {
    func toPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault,
                                  Int(size.width), Int(size.height),
                                  kCVPixelFormatType_32BGRA,
                                  attrs as CFDictionary,
                                  &buffer) == kCVReturnSuccess,
              let pixelBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: data,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue |
                                            CGBitmapInfo.byteOrder32Little.rawValue)
        context?.interpolationQuality = .none
        context?.draw(self, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }
}

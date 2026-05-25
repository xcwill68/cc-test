import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

final class GIFExportService {
    static let shared = GIFExportService()

    func export(frames: [CGImage], fps: Int) async throws -> URL {
        let outputURL = temporaryURL(extension: "gif")
        let delayTime = 1.0 / Double(fps)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw ExportError.destinationCreationFailed
        }

        let gifProperties: CFDictionary = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0  // 0 = infinite
            ]
        ] as CFDictionary

        let frameProperties: CFDictionary = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delayTime,
                kCGImagePropertyGIFUnclampedDelayTime: delayTime
            ]
        ] as CFDictionary

        CGImageDestinationSetProperties(destination, gifProperties)
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.finalizeFailed
        }
        return outputURL
    }

    private func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("roamie_\(UUID().uuidString).\(ext)")
    }

    enum ExportError: LocalizedError {
        case destinationCreationFailed, finalizeFailed
        var errorDescription: String? {
            switch self {
            case .destinationCreationFailed: return "无法创建 GIF 文件"
            case .finalizeFailed:            return "GIF 写入失败"
            }
        }
    }
}

import Foundation
import MapKit
import UIKit

enum PixelMapStyle: Int, Codable, CaseIterable, Identifiable {
    case terrain
    case political

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .terrain:  return "像素地形"
        case .political: return "像素政区"
        }
    }

    var iconSystemName: String {
        switch self {
        case .terrain:  return "mountain.2"
        case .political: return "map"
        }
    }

    var mapConfiguration: MKStandardMapConfiguration {
        switch self {
        case .terrain:
            let config = MKStandardMapConfiguration(elevationStyle: .realistic)
            config.pointOfInterestFilter = .excludingAll
            return config
        case .political:
            let config = MKStandardMapConfiguration(elevationStyle: .flat)
            config.pointOfInterestFilter = .excludingAll
            return config
        }
    }

    // Low-res capture size → pixelated effect when scaled up
    var snapshotCaptureSize: CGSize { CGSize(width: 120, height: 120) }

    var outputSize: CGSize { CGSize(width: 720, height: 720) }

    // CIPixellate block size in the final image
    var pixelBlockSize: CGFloat { 6.0 }

    // CIColorPosterize levels
    var posterizeLevels: Float { 5.0 }

    var routeColor: UIColor {
        switch self {
        case .terrain:  return UIColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 1)
        case .political: return UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1)
        }
    }

    var dotColor: UIColor {
        switch self {
        case .terrain:  return UIColor(red: 1.0, green: 0.88, blue: 0.20, alpha: 1)
        case .political: return UIColor(red: 1.0, green: 0.38, blue: 0.38, alpha: 1)
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .terrain:  return UIColor(red: 0.14, green: 0.22, blue: 0.16, alpha: 1)
        case .political: return UIColor(red: 0.10, green: 0.14, blue: 0.26, alpha: 1)
        }
    }
}

// MARK: - Character Assets

enum CharacterAsset: String, CaseIterable, Identifiable {
    case carFlag  = "car_flag"
    case plane    = "plane"
    case train    = "train"
    case traveler = "traveler"

    var id: String { rawValue }

    var assetName: String { rawValue }

    var displayName: String {
        switch self {
        case .carFlag:  return "旗帜小车"
        case .plane:    return "像素飞机"
        case .train:    return "蒸汽火车"
        case .traveler: return "背包旅者"
        }
    }

    var emoji: String {
        switch self {
        case .carFlag:  return "🚗"
        case .plane:    return "✈️"
        case .train:    return "🚂"
        case .traveler: return "🧍"
        }
    }

    // Number of animation frames in the sprite sheet
    var frameCount: Int { 4 }

    // Sprite sheet dimensions: frameCount columns × 1 row, each cell is spriteSize
    var spriteSize: CGSize { CGSize(width: 32, height: 32) }
}

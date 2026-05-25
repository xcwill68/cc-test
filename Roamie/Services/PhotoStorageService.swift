import UIKit
import PhotosUI

final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let directory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("WaypointPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Save

    func save(image: UIImage, for waypointID: UUID) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw PhotoError.compressionFailed
        }
        let fileName = "\(waypointID.uuidString)_\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    // MARK: - Load

    func load(fileName: String) -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(fileName: String, size: CGSize = CGSize(width: 80, height: 80)) -> UIImage? {
        load(fileName: fileName)?.thumbnailFit(in: size)
    }

    // MARK: - Delete

    func delete(fileName: String) {
        let url = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAll(fileNames: [String]) { fileNames.forEach { delete(fileName: $0) } }

    // MARK: - PhotosPickerItem processing (SwiftUI Photos picker)

    func process(pickerItems: [PhotosPickerItem]) async -> [UIImage] {
        await withTaskGroup(of: UIImage?.self) { group in
            for item in pickerItems {
                group.addTask { await self.loadImage(from: item) }
            }
            var images: [UIImage] = []
            for await image in group {
                if let image { images.append(image) }
            }
            return images
        }
    }

    private func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }

    enum PhotoError: LocalizedError {
        case compressionFailed
        var errorDescription: String? { "图片压缩失败" }
    }
}

private extension UIImage {
    func thumbnailFit(in size: CGSize) -> UIImage {
        let scale = min(size.width / self.size.width, size.height / self.size.height)
        let newSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

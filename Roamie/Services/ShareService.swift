import UIKit
import Photos

@MainActor
final class ShareService {
    static let shared = ShareService()

    // MARK: - Generic iOS Share Sheet

    func presentShareSheet(from viewController: UIViewController, items: [Any]) {
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.excludedActivityTypes = [.assignToContact, .addToReadingList]
        if let popover = activity.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                        y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        viewController.present(activity, animated: true)
    }

    // MARK: - Save to Photos

    func saveToPhotos(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ShareError.photoLibraryDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    func saveGIFToPhotos(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ShareError.photoLibraryDenied
        }
        let data = try Data(contentsOf: url)
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    // MARK: - Platform URL Schemes

    func shareToWeChat(imageURL: URL) {
        guard UIApplication.shared.canOpenURL(URL(string: "weixin://")!) else { return }
        UIPasteboard.general.image = UIImage(contentsOfFile: imageURL.path)
        UIApplication.shared.open(URL(string: "weixin://dl/moments")!)
    }

    func shareToWeibo(imageURL: URL, text: String) {
        guard UIApplication.shared.canOpenURL(URL(string: "weibosdk3.3://")!) else { return }
        UIPasteboard.general.image = UIImage(contentsOfFile: imageURL.path)
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        UIApplication.shared.open(URL(string: "weibosdk3.3://text?&text=\(encodedText)")!)
    }

    func shareToInstagram(imageURL: URL) {
        guard UIApplication.shared.canOpenURL(URL(string: "instagram://")!) else { return }
        UIPasteboard.general.image = UIImage(contentsOfFile: imageURL.path)
        UIApplication.shared.open(URL(string: "instagram://app")!)
    }

    enum ShareError: LocalizedError {
        case photoLibraryDenied
        var errorDescription: String? { "请在设置中允许访问照片库" }
    }
}

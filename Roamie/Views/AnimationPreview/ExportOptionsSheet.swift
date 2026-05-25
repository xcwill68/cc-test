import SwiftUI

struct ExportOptionsSheet: View {
    let trip: Trip
    let viewModel: AnimationPreviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("保存到相册") {
                    exportRow(title: "保存 GIF 动图", icon: "photo.on.rectangle.angled") {
                        viewModel.exportGIF()
                        observeAndSaveToPhotos(isGIF: true)
                    }
                    if trip.hasAnyPhotos {
                        exportRow(title: "保存含照片视频", icon: "video.badge.plus") {
                            viewModel.exportVideo()
                            observeAndSaveToPhotos(isGIF: false)
                        }
                    }
                }

                Section("系统分享") {
                    exportRow(title: "分享 GIF", icon: "square.and.arrow.up") {
                        viewModel.exportGIF()
                        observeAndPresentShare(isGIF: true)
                    }
                    if trip.hasAnyPhotos {
                        exportRow(title: "分享含照片视频", icon: "square.and.arrow.up.fill") {
                            viewModel.exportVideo()
                            observeAndPresentShare(isGIF: false)
                        }
                    }
                }

                Section("社交平台") {
                    platformRow(title: "分享到微信", icon: "message.fill", tint: .green) {
                        viewModel.exportGIF()
                        observeAndShare(isGIF: true) { url in
                            ShareService.shared.shareToWeChat(imageURL: url)
                        }
                    }
                    platformRow(title: "分享到微博", icon: "globe", tint: .orange) {
                        viewModel.exportGIF()
                        observeAndShare(isGIF: true) { url in
                            ShareService.shared.shareToWeibo(imageURL: url,
                                                             text: "我的旅程：\(trip.title) #Roamie#")
                        }
                    }
                    platformRow(title: "分享到 Instagram", icon: "camera.fill", tint: .purple) {
                        viewModel.exportGIF()
                        observeAndShare(isGIF: true) { url in
                            ShareService.shared.shareToInstagram(imageURL: url)
                        }
                    }
                }

                if viewModel.isExporting {
                    HStack { Spacer(); ProgressView("导出中…"); Spacer() }
                }
                if let err = viewModel.errorMessage {
                    ErrorBanner(message: err)
                }
            }
            .navigationTitle("导出分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - Builders

    @ViewBuilder
    private func exportRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .disabled(viewModel.isExporting || viewModel.frames.isEmpty)
    }

    @ViewBuilder
    private func platformRow(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title)
            }
        }
        .disabled(viewModel.isExporting || viewModel.frames.isEmpty)
    }

    // MARK: - Async share helpers

    private func observeAndSaveToPhotos(isGIF: Bool) {
        Task {
            await waitForExport(isGIF: isGIF) { url in
                if isGIF {
                    try? await ShareService.shared.saveGIFToPhotos(url: url)
                } else {
                    try? await ShareService.shared.saveToPhotos(url: url)
                }
            }
        }
    }

    private func observeAndPresentShare(isGIF: Bool) {
        Task {
            await waitForExport(isGIF: isGIF) { url in
                await MainActor.run {
                    guard let vc = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first?.windows.first?.rootViewController else { return }
                    ShareService.shared.presentShareSheet(from: vc, items: [url])
                }
            }
        }
    }

    private func observeAndShare(isGIF: Bool, action: @escaping @MainActor (URL) -> Void) {
        Task {
            await waitForExport(isGIF: isGIF) { url in
                await MainActor.run { action(url) }
            }
        }
    }

    private func waitForExport(isGIF: Bool, then action: (URL) async -> Void) async {
        var attempts = 0
        while attempts < 60 {
            if let url = isGIF ? viewModel.gifURL : viewModel.videoURL {
                await action(url)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
            attempts += 1
        }
    }
}

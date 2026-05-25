import SwiftUI

struct AnimationPreviewView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AnimationPreviewViewModel()
    @State private var selectedMode: ExportMode = .gif
    @State private var playbackTimer: Timer?
    @State private var isShowingExport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview player (square aspect, black background)
                ZStack {
                    Color.black
                    if viewModel.isRendering {
                        renderingOverlay
                    } else if !viewModel.frames.isEmpty {
                        framePreview
                    } else {
                        startPlaceholder
                    }
                }
                .aspectRatio(1, contentMode: .fit)

                // Controls
                VStack(spacing: 16) {
                    if !viewModel.isRendering && !viewModel.frames.isEmpty {
                        modeSelector
                    }
                    actionButtons
                    if let err = viewModel.errorMessage {
                        ErrorBanner(message: err)
                    }
                }
                .padding()
            }
            .navigationTitle("旅行动图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        viewModel.cancelRender()
                        stopPlayback()
                        dismiss()
                    }
                }
            }
            .onAppear { startRender() }
            .onChange(of: viewModel.frames) { _, frames in
                if !frames.isEmpty { startPlayback() }
            }
            .sheet(isPresented: $isShowingExport) {
                ExportOptionsSheet(trip: trip, viewModel: viewModel)
            }
        }
    }

    // MARK: - Subviews

    private var renderingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView(value: viewModel.renderProgress)
                .tint(.orange)
                .padding(.horizontal, 40)
            Text("正在生成 \(Int(viewModel.renderProgress * 100))%")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder
    private var framePreview: some View {
        if !viewModel.frames.isEmpty {
            let frame = viewModel.frames[viewModel.currentFrameIndex % viewModel.frames.count]
            Image(decorative: frame, scale: 1)
                .resizable()
                .interpolation(.none)  // Preserve pixel art sharpness
                .scaledToFit()
        }
    }

    private var startPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("准备生成动图…")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var modeSelector: some View {
        Picker("模式", selection: $selectedMode) {
            Text("GIF 动图").tag(ExportMode.gif)
            if trip.hasAnyPhotos {
                Text("含照片视频").tag(ExportMode.video)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedMode) { _, _ in
            stopPlayback()
            startRender()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                stopPlayback()
                startRender()
            } label: {
                Label("重新生成", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isRendering)

            Button {
                isShowingExport = true
            } label: {
                Label("导出分享", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(viewModel.frames.isEmpty || viewModel.isRendering)
        }
    }

    // MARK: - Playback

    private func startPlayback() {
        stopPlayback()
        let fps: Double = selectedMode == .gif ? 12 : 30
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            guard !viewModel.frames.isEmpty else { return }
            viewModel.currentFrameIndex = (viewModel.currentFrameIndex + 1) % viewModel.frames.count
        }
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func startRender() {
        viewModel.startRender(trip: trip, mode: selectedMode)
    }
}

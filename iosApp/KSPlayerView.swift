import SwiftUI
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer，inline + fullscreen 分治：
///
/// - **inline 模式**：用底层 `KSVideoPlayer`（仅显示视频内容，无内置 UI），叠加一组最小
///   控件 —— 中央播放/暂停按钮 + 右上全屏按钮，仅靠单击/双击触发。
///   这部分必须自己写，因为 KSPlayer 上游的所有完整 player view（`IOSVideoPlayerView` /
///   `KSVideoPlayerView`）都是为 fullscreen 设计的，inline 嵌入时它们的内部修饰符
///   （`.ignoresSafeArea` / `.toolbar(.hidden, for: .automatic)` /
///   `.persistentSystemOverlays(.hidden)`）会破坏外层 NavigationStack 的 toolbar 与
///   边缘返回手势；公共 `KSVideoPlayerViewBuilder` 也只提供单按钮 helper，不提供完整 inline 控件。
///
/// - **fullscreen 模式**：用 `KSVideoPlayerView`（上游完整 SwiftUI player view，自带
///   控件 / 字幕 / PiP / 倍速 / 清晰度切换 / AirPlay / 长按倍速等手势）。通过
///   `.fullScreenCover` 弹出；共享同一 `KSVideoPlayer.Coordinator`，KSPlayerLayer 复用，
///   不会重新加载视频或重置进度。进入时锁横屏，退出时恢复方向。
///
/// 部署目标 iOS 16+。
@MainActor
struct KSPlayerView: View {
    let snapshot: VideoDetailScreenSnapshot
    let onProgress: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var showsControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isPlaying = false
    @State private var showsFullscreen = false

    init(
        snapshot: VideoDetailScreenSnapshot,
        onProgress: @escaping (TimeInterval) -> Void = { _ in },
        onPlaybackEnded: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onProgress = onProgress
        self.onPlaybackEnded = onPlaybackEnded
    }

    var body: some View {
        let _ = Self.configureKSPlayerGlobalsOnce
        Group {
            if let primarySource = Self.primarySource(in: snapshot),
               let url = URL(string: primarySource.url) {
                inlinePlayer(url: url)
                    .fullScreenCover(isPresented: $showsFullscreen) {
                        FullscreenKSPlayerView(
                            coordinator: coordinator,
                            snapshot: snapshot,
                            onClose: { showsFullscreen = false }
                        )
                    }
            } else {
                emptyPlaceholder
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipped()
    }

    // MARK: - Inline player + minimal controls

    @ViewBuilder
    private func inlinePlayer(url: URL) -> some View {
        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
        let options = Self.makeKSOptions(resumeSeconds: resumeSeconds)

        ZStack {
            KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                .onPlay { current, _ in
                    if current.isFinite { onProgress(current) }
                }
                .onFinish { _, _ in
                    onPlaybackEnded()
                }
                .onStateChanged { _, state in
                    isPlaying = state.isPlaying
                }

            if showsControls {
                inlineControlsOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            togglePlayPause()
            scheduleAutoHide()
        }
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.18)) { showsControls.toggle() }
            if showsControls { scheduleAutoHide() }
        }
        .onAppear { scheduleAutoHide() }
        .onDisappear { hideControlsTask?.cancel() }
    }

    private var inlineControlsOverlay: some View {
        ZStack {
            // 顶部 + 底部薄渐变让按钮可读
            LinearGradient(
                colors: [.black.opacity(0.4), .clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    fullscreenButton
                }
                Spacer()
                centerPlayPauseButton
                Spacer()
            }
            .padding(12)
        }
    }

    private var fullscreenButton: some View {
        Button { showsFullscreen = true } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.45), in: Circle())
                .accessibilityLabel("全屏")
        }
        .buttonStyle(.plain)
    }

    private var centerPlayPauseButton: some View {
        Button {
            togglePlayPause()
            scheduleAutoHide()
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(.white)
                .shadow(radius: 4)
                .accessibilityLabel(isPlaying ? "暂停" : "播放")
        }
        .buttonStyle(.plain)
    }

    private var emptyPlaceholder: some View {
        ZStack {
            Color.black
            VStack(spacing: 10) {
                Image(systemName: "play.slash")
                    .font(.title)
                    .foregroundStyle(.white)
                Text("未解析到可播放源")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Helpers

    private func togglePlayPause() {
        guard let layer = coordinator.playerLayer else { return }
        if isPlaying { layer.pause() } else { layer.play() }
    }

    private func scheduleAutoHide() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000) // 4.5s
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showsControls = false
            }
        }
    }

    // MARK: - Static helpers (shared with FullscreenKSPlayerView)

    static func primarySource(in snapshot: VideoDetailScreenSnapshot) -> VideoPlaybackSourceRow? {
        snapshot.playbackSources.first(where: { $0.isDefault }) ?? snapshot.playbackSources.first
    }

    static func makeKSOptions(resumeSeconds: TimeInterval) -> KSOptions {
        let options = KSOptions()
        // hanime1.me 视频 CDN 通常需要正确的 UA 和 Referer 才能播放。
        options.appendHeader([
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Referer": "https://hanime1.me/",
        ])
        options.isSeekedAutoPlay = true
        options.isAccurateSeek = true
        if resumeSeconds > 1 {
            options.startPlayTime = resumeSeconds
        }
        return options
    }

    /// KSPlayer 一次性全局配置：自动播放 + 后台音频会话（解决审计 P0-L1 的一半）。
    private static let configureKSPlayerGlobalsOnce: Void = {
        KSOptions.isAutoPlay = true
        KSOptions.setAudioSession()
    }()
}

// MARK: - Fullscreen player

/// 全屏 player：直接用上游 `KSVideoPlayerView`，自带完整控件 / 字幕 / PiP / 倍速 /
/// 清晰度切换 / AirPlay / 长按倍速等手势。共享 inline `Coordinator`，不重新加载视频。
@MainActor
private struct FullscreenKSPlayerView: View {
    @ObservedObject var coordinator: KSVideoPlayer.Coordinator
    let snapshot: VideoDetailScreenSnapshot
    let onClose: () -> Void

    var body: some View {
        Group {
            if let primarySource = KSPlayerView.primarySource(in: snapshot),
               let url = URL(string: primarySource.url) {
                let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
                let options = KSPlayerView.makeKSOptions(resumeSeconds: resumeSeconds)

                KSVideoPlayerView(
                    coordinator: coordinator,
                    url: url,
                    options: options,
                    title: snapshot.title
                )
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            AppOrientationController.shared.lockForFullscreen(to: .landscape)
        }
        .onDisappear {
            AppOrientationController.shared.unlockAfterFullscreen()
        }
        // KSVideoPlayerView 内部的 dismiss 通过 @Environment(\.dismiss) 触发；fullScreenCover
        // 自动响应。这里仅在 onDisappear 通知父 view 状态同步。
    }
}

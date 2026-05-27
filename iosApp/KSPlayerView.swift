import SwiftUI
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer，inline + fullscreen 分治：
///
/// - **inline 模式**：用底层 `KSVideoPlayer`（仅显示视频内容，无内置 UI），叠加最小
///   控件 —— 中央播放/暂停按钮 + 右上全屏按钮，靠单击/双击触发。
/// - **fullscreen 模式**：用 `KSVideoPlayerView`（上游完整 SwiftUI player view，
///   含字幕 / PiP / 倍速 / 清晰度 / AirPlay / 长按倍速 / 滑动调音量亮度 seek）。
///
/// 关键点：**inline 和 fullscreen 各自一个 `KSVideoPlayer.Coordinator`**，不能共享。
/// KSPlayer 的 `KSVideoPlayer.dismantleUIView` 会调用 `coordinator.resetPlayer()`，
/// 把 `playerLayer` 置 nil 并清空所有回调。如果 inline 和 fullscreen 共享 coordinator，
/// fullscreen 关闭瞬间 dismantle 会破坏 inline（inline 失去回调 + playerLayer，
/// 必须重新加载视频且 isPlaying 等 state 不再同步）。
///
/// 进度同步策略：
/// - inline 的 `onPlay` 持续把 currentTime 记到 `lastInlineCurrentTime`
/// - 点全屏按钮：先暂停 inline，把 `lastInlineCurrentTime` 作为 fullscreen 的 startTime
/// - fullscreen 的 `onPlay` 把 currentTime 记到 `lastFullscreenCurrentTime`
/// - 退出全屏（`onDismiss`）：inline 的 playerLayer 仍存在，seek 到
///   `lastFullscreenCurrentTime` 并 play，从全屏看到的位置继续
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
    @State private var lastInlineCurrentTime: TimeInterval = 0
    @State private var lastFullscreenCurrentTime: TimeInterval = 0

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
                    .fullScreenCover(
                        isPresented: $showsFullscreen,
                        onDismiss: handleFullscreenDismiss
                    ) {
                        FullscreenKSPlayerView(
                            snapshot: snapshot,
                            startTime: lastInlineCurrentTime,
                            onProgressUpdate: { current in
                                lastFullscreenCurrentTime = current
                            },
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
                    if current.isFinite {
                        lastInlineCurrentTime = current
                        onProgress(current)
                    }
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
        Button {
            // 进入全屏前暂停 inline，避免 inline 与 fullscreen 同时播放（音频/带宽冲突）。
            coordinator.playerLayer?.pause()
            showsFullscreen = true
        } label: {
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

    private func handleFullscreenDismiss() {
        // 退出全屏：把 fullscreen 看到的进度同步回 inline，恢复 inline 播放。
        // inline 的 KSPlayerLayer 在全屏期间没有被 dismantle（inline view 仍在 view tree
        // 中，只是被 fullScreenCover 遮挡），所以 seek 直接生效。
        if lastFullscreenCurrentTime > 0 {
            coordinator.playerLayer?.seek(time: lastFullscreenCurrentTime)
        }
        coordinator.playerLayer?.play()
        // 同步给本地观看历史
        if lastFullscreenCurrentTime.isFinite {
            onProgress(lastFullscreenCurrentTime)
        }
        // 重置全屏进度记录
        lastFullscreenCurrentTime = 0
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

/// 全屏 player：用上游 `KSVideoPlayerView` 自带完整 UI。
/// **使用独立的 KSVideoPlayer.Coordinator**，与 inline 不共享 —— 因为 KSPlayer 的
/// `dismantleUIView` 会 `resetPlayer`，会破坏共享的 inline state。代价是视频要重新
/// 加载（约 1-2 秒延迟），但 inline 状态稳定，退出后能从 fullscreen 看到的进度继续。
@MainActor
private struct FullscreenKSPlayerView: View {
    let snapshot: VideoDetailScreenSnapshot
    let startTime: TimeInterval
    let onProgressUpdate: (TimeInterval) -> Void
    let onClose: () -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    var body: some View {
        Group {
            if let primarySource = KSPlayerView.primarySource(in: snapshot),
               let url = URL(string: primarySource.url) {
                let options = KSPlayerView.makeKSOptions(resumeSeconds: startTime)
                KSVideoPlayerView(
                    coordinator: coordinator,
                    url: url,
                    options: options,
                    title: snapshot.title
                )
                .onAppear {
                    // 持续把 fullscreen 的进度回写给外层，供退出时同步给 inline。
                    coordinator.onPlay = { current, _ in
                        if current.isFinite {
                            onProgressUpdate(current)
                        }
                    }
                }
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
    }
}

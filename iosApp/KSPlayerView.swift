import SwiftUI
import UIKit
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer 的**底层** `KSVideoPlayer`（不是 `IOSVideoPlayerView`）。
///
/// 设计取舍：
/// - `IOSVideoPlayerView` 是 KSPlayer 提供的"完整 player UI"（自带 top bar / 控件 / 全屏）
///   但它的内部 Auto Layout 强制为全屏使用设计，inline 嵌入小 frame 时 toolbar 与
///   外部 SwiftUI frame 冲突，撑出 16:9 比例（已在 iPhone / iPad split panel 上验证失败）。
/// - `KSVideoPlayerView` (iOS 16+) 也是为全屏设计（用 `ignoresSafeArea` 等修饰符）。
/// - **`KSVideoPlayer` 是底层 `UIViewRepresentable`，仅显示视频内容（无内置 UI）**，
///   inline 嵌入完全友好；项目支持 iOS 15+，KSVideoPlayer 没有 iOS 16 限制。
///
/// 控件用 SwiftUI 自己写在 ZStack 上层，并实现"中国式"播放器手势：
/// - 单击：toggle 控件显示
/// - 双击：播放/暂停
/// - 长按 0.4s+：进入 2x 倍速；松开恢复原速
/// - 双指 pinch：切换 fit ⇔ fill 模式
/// - 中央按钮：播放/暂停
/// - 底部进度条：当前/总时长
/// - 右上角全屏按钮：fullScreenCover + 共享 coordinator + 强制横屏
@MainActor
struct KSPlayerView: View {
    let snapshot: VideoDetailScreenSnapshot
    let onProgress: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var showsControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var currentSeconds: TimeInterval = 0
    @State private var totalSeconds: TimeInterval = 0
    @State private var isPlaying: Bool = false
    @State private var showsFullscreen = false
    @State private var savedPlaybackRate: Float = 1.0
    @State private var isBoosted: Bool = false

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
        // 一次性全局配置 KSPlayer（自动播放 + 后台音频会话，解决审计 P0-L1 一半）
        let _ = Self.configureKSPlayerGlobalsOnce
        Group {
            if let primarySource = Self.primarySource(in: snapshot),
               let url = URL(string: primarySource.url) {
                playerWithControls(url: url)
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
        .background(Color.black)
        .clipped()
    }

    // MARK: - Inline player + controls + gestures

    @ViewBuilder
    private func playerWithControls(url: URL) -> some View {
        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
        let options = Self.makeKSOptions(resumeSeconds: resumeSeconds)

        ZStack {
            // 视频内容层
            KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                .onPlay { current, total in
                    if current.isFinite { currentSeconds = current }
                    if total.isFinite { totalSeconds = total }
                    onProgress(current)
                }
                .onFinish { _, _ in
                    onPlaybackEnded()
                }
                .onStateChanged { _, state in
                    isPlaying = state.isPlaying
                }

            // 长按倍速 hint
            if isBoosted {
                VStack {
                    HStack {
                        Spacer()
                        Label("2x", systemImage: "forward.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            // 控件层
            if showsControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        // 双击：播放/暂停
        .onTapGesture(count: 2) {
            togglePlayPause()
            scheduleAutoHide()
        }
        // 单击：切换控件可见性
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.18)) {
                showsControls.toggle()
            }
            if showsControls { scheduleAutoHide() }
        }
        // 长按 0.4s+ 进入 2x 倍速；松开恢复
        .onLongPressGesture(
            minimumDuration: 0.4,
            pressing: { isPressing in
                if !isPressing, isBoosted {
                    endBoost()
                }
            },
            perform: {
                startBoost()
            }
        )
        // 双指 pinch 切换 fit/fill
        .simultaneousGesture(
            MagnificationGesture()
                .onEnded { value in
                    coordinator.isScaleAspectFill = value > 1.1
                }
        )
        .onAppear { scheduleAutoHide() }
        .onDisappear { hideControlsTask?.cancel() }
    }

    private var controlsOverlay: some View {
        ZStack {
            // 上下渐变蒙版让按钮更清晰
            LinearGradient(
                colors: [.black.opacity(0.45), .clear, .black.opacity(0.55)],
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
                bottomProgressBar
            }
            .padding(12)
        }
    }

    private var fullscreenButton: some View {
        Button {
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

    private var bottomProgressBar: some View {
        HStack(spacing: 10) {
            Text(Self.formatTime(currentSeconds))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
            ProgressView(value: progressFraction)
                .progressViewStyle(.linear)
                .tint(.white)
            Text(Self.formatTime(totalSeconds))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
        }
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
        if isPlaying {
            layer.pause()
        } else {
            layer.play()
        }
    }

    private func startBoost() {
        guard !isBoosted else { return }
        savedPlaybackRate = coordinator.playbackRate
        coordinator.playbackRate = 2.0
        withAnimation(.easeInOut(duration: 0.15)) { isBoosted = true }
    }

    private func endBoost() {
        guard isBoosted else { return }
        coordinator.playbackRate = savedPlaybackRate
        withAnimation(.easeInOut(duration: 0.15)) { isBoosted = false }
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

    private var progressFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(max(currentSeconds / totalSeconds, 0), 1)
    }

    // MARK: - Static helpers (shared with FullscreenKSPlayerView)

    static func primarySource(in snapshot: VideoDetailScreenSnapshot) -> VideoPlaybackSourceRow? {
        snapshot.playbackSources.first(where: { $0.isDefault }) ?? snapshot.playbackSources.first
    }

    static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    static func makeKSOptions(resumeSeconds: TimeInterval) -> KSOptions {
        let options = KSOptions()
        // hanime1.me 视频 CDN 通常需要正确的 UA 和 Referer 才能播放。
        // 用 KSOptions.appendHeader 同时写入 AVURLAsset 和 FFmpeg 两条 backend 路径。
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
    /// 注意：`KSOptions.isAutoPlay` 在最新版 KSPlayer 是 static，不能在 instance 上设置。
    private static let configureKSPlayerGlobalsOnce: Void = {
        KSOptions.isAutoPlay = true
        KSOptions.setAudioSession()
    }()
}

// MARK: - Fullscreen player

/// 全屏 player 视图。和 inline 的 KSPlayerView 共享同一 `KSVideoPlayer.Coordinator`，
/// 复用底层 `KSPlayerLayer.player`（不重新加载视频，不重置进度）。
/// 进入时强制横屏，退出时恢复原方向。
@MainActor
private struct FullscreenKSPlayerView: View {
    @ObservedObject var coordinator: KSVideoPlayer.Coordinator
    let snapshot: VideoDetailScreenSnapshot
    let onClose: () -> Void

    @State private var showsControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var currentSeconds: TimeInterval = 0
    @State private var totalSeconds: TimeInterval = 0
    @State private var isPlaying: Bool = false
    @State private var savedPlaybackRate: Float = 1.0
    @State private var isBoosted: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let primarySource = KSPlayerView.primarySource(in: snapshot),
               let url = URL(string: primarySource.url) {
                let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
                let options = KSPlayerView.makeKSOptions(resumeSeconds: resumeSeconds)

                KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                    .onPlay { current, total in
                        if current.isFinite { currentSeconds = current }
                        if total.isFinite { totalSeconds = total }
                    }
                    .onStateChanged { _, state in
                        isPlaying = state.isPlaying
                    }
                    .ignoresSafeArea()
            }

            if isBoosted {
                VStack {
                    HStack {
                        Spacer()
                        Label("2x", systemImage: "forward.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.trailing, 24)
                .transition(.opacity)
            }

            if showsControls {
                fullscreenControlsOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            togglePlayPause()
            scheduleAutoHide()
        }
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.18)) {
                showsControls.toggle()
            }
            if showsControls { scheduleAutoHide() }
        }
        .onLongPressGesture(
            minimumDuration: 0.4,
            pressing: { isPressing in
                if !isPressing, isBoosted {
                    endBoost()
                }
            },
            perform: {
                startBoost()
            }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onEnded { value in
                    coordinator.isScaleAspectFill = value > 1.1
                }
        )
        .onAppear {
            AppOrientationController.shared.lockForFullscreen(to: .landscape)
            scheduleAutoHide()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            AppOrientationController.shared.unlockAfterFullscreen()
        }
        .preferredColorScheme(.dark)
    }

    private var fullscreenControlsOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .accessibilityLabel("退出全屏")
                    Spacer()
                }
                Spacer()
                Button {
                    togglePlayPause()
                    scheduleAutoHide()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 80, weight: .regular))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                }
                .buttonStyle(.plain)
                Spacer()
                HStack(spacing: 12) {
                    Text(KSPlayerView.formatTime(currentSeconds))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.white)
                    ProgressView(value: progressFraction)
                        .progressViewStyle(.linear)
                        .tint(.white)
                    Text(KSPlayerView.formatTime(totalSeconds))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }

    private func togglePlayPause() {
        guard let layer = coordinator.playerLayer else { return }
        if isPlaying { layer.pause() } else { layer.play() }
    }

    private func startBoost() {
        guard !isBoosted else { return }
        savedPlaybackRate = coordinator.playbackRate
        coordinator.playbackRate = 2.0
        withAnimation(.easeInOut(duration: 0.15)) { isBoosted = true }
    }

    private func endBoost() {
        guard isBoosted else { return }
        coordinator.playbackRate = savedPlaybackRate
        withAnimation(.easeInOut(duration: 0.15)) { isBoosted = false }
    }

    private func scheduleAutoHide() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showsControls = false
            }
        }
    }

    private var progressFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(max(currentSeconds / totalSeconds, 0), 1)
    }
}

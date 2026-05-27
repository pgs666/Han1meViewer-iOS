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
/// 控件用 SwiftUI 自己写在 ZStack 上层：
/// - 单击屏幕：toggle 控件显示
/// - 中央：播放/暂停按钮
/// - 底部：进度条 + 当前/总时长
/// - cookie 不注入；UA + Referer 通过 `KSOptions.appendHeader` 写入两条 backend
/// - 长按倍速 / 双指缩放等手势作为后续 increment 加，spike 阶段先满足"能正常播放 + 不破坏布局"。
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
            if let primarySource = primarySource(),
               let url = URL(string: primarySource.url) {
                playerWithControls(url: url)
            } else {
                emptyPlaceholder
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .background(Color.black)
        .clipped()
    }

    // MARK: - Player + Controls

    @ViewBuilder
    private func playerWithControls(url: URL) -> some View {
        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
        let options = makeKSOptions(resumeSeconds: resumeSeconds)

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

            // 控件层（半透明渐变 + 中央播放按钮 + 底部进度条）
            if showsControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                showsControls.toggle()
            }
            if showsControls {
                scheduleAutoHide()
            }
        }
        .onAppear {
            scheduleAutoHide()
        }
        .onDisappear {
            hideControlsTask?.cancel()
        }
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
                Spacer()
                centerPlayPauseButton
                Spacer()
                bottomProgressBar
            }
            .padding(12)
        }
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
            Text(formatTime(currentSeconds))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
            ProgressView(value: progressFraction)
                .progressViewStyle(.linear)
                .tint(.white)
            Text(formatTime(totalSeconds))
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

    private func primarySource() -> VideoPlaybackSourceRow? {
        snapshot.playbackSources.first(where: { $0.isDefault }) ?? snapshot.playbackSources.first
    }

    private func togglePlayPause() {
        guard let layer = coordinator.playerLayer else { return }
        if isPlaying {
            layer.pause()
        } else {
            layer.play()
        }
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

    private func formatTime(_ seconds: TimeInterval) -> String {
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

    private func makeKSOptions(resumeSeconds: TimeInterval) -> KSOptions {
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

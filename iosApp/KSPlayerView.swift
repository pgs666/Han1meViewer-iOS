import SwiftUI
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer 的底层 `KSVideoPlayer`（仅显示视频内容，无内置 UI），
/// 控件层用上游公共 `KSVideoPlayerViewBuilder` 的 helper 按钮（subtitle / contentMode /
/// playback control / playback rate）拼装，再叠加自己写的手势 / 进度条 / 全屏切换 / 收起。
///
/// 之前用过完整的 `KSVideoPlayerView`，但它内部带 `.preferredColorScheme(.dark)`、
/// `.toolbar(.hidden, for: .automatic)`、`.persistentSystemOverlays(.hidden)` 等
/// "全屏向"修饰符。SwiftUI 的 `preferredColorScheme` 是 PreferenceKey 会一直 propagate
/// 到 root window，**嵌套 `NavigationStack` 不能隔离**。这会让外层整个 app 进入 dark mode。
/// 所以 inline 不能直接用 `KSVideoPlayerView`。
///
/// 通过 `@Binding isFullscreen` / `@Binding isCollapsed` 让外部容器（VideoDetailView）
/// 控制 player 形态：
/// - **inline**：16:9 frame
/// - **fullscreen**：撑满父容器（VideoDetailView 进入全屏 layout）
/// - **collapsed**：暂停后用户点收起 → 50pt 折叠 strip
///
/// **关键**：KSPlayerView 始终在 SwiftUI view tree 同一位置，仅靠外层 frame 切换大小，
/// view identity 不变 → KSPlayerLayer 复用 → 视频不重新加载，进度不丢失。
@MainActor
struct KSPlayerView: View {
    let snapshot: VideoDetailScreenSnapshot
    @Binding var isFullscreen: Bool
    @Binding var isCollapsed: Bool
    let onProgress: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var showsControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isPlaying = false
    @State private var currentSeconds: TimeInterval = 0
    @State private var totalSeconds: TimeInterval = 0
    @State private var savedPlaybackRate: Float = 1.0
    @State private var isBoosted = false

    init(
        snapshot: VideoDetailScreenSnapshot,
        isFullscreen: Binding<Bool>,
        isCollapsed: Binding<Bool>,
        onProgress: @escaping (TimeInterval) -> Void = { _ in },
        onPlaybackEnded: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self._isFullscreen = isFullscreen
        self._isCollapsed = isCollapsed
        self.onProgress = onProgress
        self.onPlaybackEnded = onPlaybackEnded
    }

    var body: some View {
        let _ = Self.configureKSPlayerGlobalsOnce
        Group {
            if isCollapsed {
                collapsedStrip
            } else if let primarySource = primarySource(),
                      let url = URL(string: primarySource.url) {
                playerWithControls(url: url)
            } else {
                emptyPlaceholder
            }
        }
        .background(Color.black)
        .clipped()
    }

    // MARK: - Player + controls

    @ViewBuilder
    private func playerWithControls(url: URL) -> some View {
        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
        let options = makeKSOptions(resumeSeconds: resumeSeconds)

        ZStack {
            KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                .onPlay { current, total in
                    if current.isFinite { currentSeconds = current; onProgress(current) }
                    if total.isFinite { totalSeconds = total }
                }
                .onFinish { _, _ in onPlaybackEnded() }
                .onStateChanged { _, state in
                    isPlaying = state.isPlaying
                }

            if isBoosted {
                boostHint.transition(.opacity)
            }

            if showsControls {
                controlsOverlay.transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        // 双击：播放/暂停
        .onTapGesture(count: 2) {
            togglePlayPause()
            scheduleAutoHide()
        }
        // 单击：toggle 控件可见
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.18)) { showsControls.toggle() }
            if showsControls { scheduleAutoHide() }
        }
        // 长按 0.4s+ 进入 2x 倍速；松开恢复
        .onLongPressGesture(
            minimumDuration: 0.4,
            pressing: { isPressing in
                if !isPressing, isBoosted { endBoost() }
            },
            perform: { startBoost() }
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
            LinearGradient(
                colors: [.black.opacity(0.5), .clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                centerControls
                Spacer()
                bottomBar
            }
            .padding(12)
            .foregroundStyle(.white)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            // 暂停时显示收起按钮（仅非全屏时有意义）
            if !isFullscreen, !isPlaying {
                iconButton(systemImage: "chevron.up", label: "收起播放器") {
                    withAnimation(.easeInOut(duration: 0.25)) { isCollapsed = true }
                }
            }
            Spacer()
            KSVideoPlayerViewBuilder.subtitleButton(config: coordinator)
                .font(.title3)
                .foregroundStyle(.white)
            KSVideoPlayerViewBuilder.contentModeButton(config: coordinator)
                .font(.title3)
                .foregroundStyle(.white)
            iconButton(
                systemImage: isFullscreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right",
                label: isFullscreen ? "退出全屏" : "全屏"
            ) {
                withAnimation(.easeInOut(duration: 0.25)) { isFullscreen.toggle() }
            }
        }
    }

    private var centerControls: some View {
        // KSPlayer 上游公共 helper：上一集 / 播放暂停 / 下一集
        KSVideoPlayerViewBuilder.playbackControlView(config: coordinator, spacing: 28)
            .font(.system(size: 32))
            .foregroundStyle(.white)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Text(Self.formatTime(currentSeconds))
                .font(.caption2.monospacedDigit())
            ProgressView(value: progressFraction)
                .progressViewStyle(.linear)
                .tint(.white)
            Text(Self.formatTime(totalSeconds))
                .font(.caption2.monospacedDigit())
            // 上游公共 helper：倍速选择
            KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $coordinator.playbackRate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var boostHint: some View {
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
    }

    private func iconButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.45), in: Circle())
                .accessibilityLabel(label)
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

    // MARK: - Collapsed strip

    private var collapsedStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(.white)
                .font(.title2)
            Text(snapshot.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            iconButton(systemImage: "chevron.down", label: "展开播放器") {
                withAnimation(.easeInOut(duration: 0.25)) { isCollapsed = false }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    // MARK: - Helpers

    private func primarySource() -> VideoPlaybackSourceRow? {
        snapshot.playbackSources.first(where: { $0.isDefault }) ?? snapshot.playbackSources.first
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

    static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func makeKSOptions(resumeSeconds: TimeInterval) -> KSOptions {
        let options = KSOptions()
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

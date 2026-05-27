import SwiftUI
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer 的底层 `KSVideoPlayer`（仅显示视频内容，无内置 UI），控件层完全
/// 自己拼装但都通过 `KSVideoPlayer.Coordinator` 的 **public API** 操作（`seek(time:)` /
/// `skip(interval:)` / `playbackRate` / `isScaleAspectFill` / `state.isPlaying` /
/// `timemodel.currentTime/totalTime`），所以播放/暂停/倍速/aspect mode/进度都跟 KSPlayer
/// 内部完全同步。
///
/// 不用上游 `KSVideoPlayerView` 的原因：它内部带 `.preferredColorScheme(.dark)` 这是
/// SwiftUI PreferenceKey，会一直 propagate 到 root window，**嵌套 NavigationStack 不能
/// 隔离**，会让外层整个 app 进入 dark mode。`KSVideoPlayerViewBuilder` 是 internal enum
/// 也用不了。
///
/// 通过 `@Binding isFullscreen` / `@Binding isCollapsed` 让外部容器（VideoDetailView）
/// 控制 player 形态。**关键**：始终在 SwiftUI view tree 同一位置，仅靠外层 frame 切换大小，
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
    @State private var isBoosted = false
    @State private var savedPlaybackRate: Float = 1.0
    /// 长按 boost 倍速。读 `long_press_speed_times` —— `PreferencesStore` 已经预留
    /// 这个 key（KMP 端 `IosPreferencesStorage` 用 NSUserDefaults，所以 Swift
    /// `@AppStorage` 直接读到同一份值）。Settings 现在把"长按倍速"绑定到这个 key。
    @AppStorage("long_press_speed_times") private var storedBoostPlaybackRate: Double = 2.0
    /// 拖动 slider 时本地暂存目标值；松手后调 coordinator.seek 并清空。
    @State private var sliderSeekTarget: TimeInterval?

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
                .onPlay { current, _ in
                    // Skip the initial 0 → ~1s burst of onPlay ticks. KSPlayer fires
                    // these BEFORE applying KSOptions.startPlayTime, and writing them
                    // to the watch-history db would overwrite the user's saved
                    // resume position with 0 every time the screen is opened.
                    if current.isFinite, current >= 2.0 {
                        onProgress(current)
                    }
                }
                .onFinish { _, _ in onPlaybackEnded() }
                .onStateChanged { _, state in
                    isPlaying = state.isPlaying
                }
                // Attach gestures to the video layer, NOT to the outer ZStack.
                // Otherwise outer .onTapGesture(count: 1) raced with Buttons /
                // Menu inside controlsOverlay — tapping the "1x" rate menu was
                // both opening the menu AND toggling showsControls, so the
                // controls (and the menu) immediately disappeared together.
                // Now Button / Menu inside controlsOverlay handle their taps
                // first (they sit on top in z-order); taps on truly empty mask
                // areas fall through (gradient is allowsHitTesting(false), the
                // VStack has natural pass-through in gaps) and reach the video
                // layer's gestures below.
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    togglePlayPause()
                    scheduleAutoHide()
                }
                .onTapGesture(count: 1) {
                    withAnimation(.easeInOut(duration: 0.18)) { showsControls.toggle() }
                    if showsControls { scheduleAutoHide() }
                }
                .onLongPressGesture(
                    minimumDuration: 0.4,
                    pressing: { isPressing in
                        if !isPressing, isBoosted { endBoost() }
                    },
                    perform: { startBoost() }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onEnded { value in
                            if !isFullscreen, value > 1.15 {
                                withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = true }
                            } else if isFullscreen, value < 0.85 {
                                withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = false }
                            }
                        }
                )

            if isBoosted {
                boostHint.transition(.opacity)
            }

            if showsControls {
                controlsOverlay.transition(.opacity)
            }
        }
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            // 暂停时收起按钮（仅非全屏时有意义）
            if !isFullscreen, !isPlaying {
                iconButton(systemImage: "chevron.up", label: "收起播放器") {
                    withAnimation(.easeInOut(duration: 0.25)) { isCollapsed = true }
                }
            }
            Spacer()
            // 静音 toggle
            iconButton(
                systemImage: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: coordinator.isMuted ? "取消静音" : "静音"
            ) {
                coordinator.isMuted.toggle()
            }
            // 比例 fit/fill
            iconButton(
                systemImage: coordinator.isScaleAspectFill
                    ? "rectangle.arrowtriangle.2.inward"
                    : "rectangle.arrowtriangle.2.outward",
                label: coordinator.isScaleAspectFill ? "适配" : "填充"
            ) {
                coordinator.isScaleAspectFill.toggle()
            }
            // 全屏 toggle
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
        HStack(spacing: 36) {
            Button {
                coordinator.skip(interval: -15)
                scheduleAutoHide()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("后退 15 秒")

            Button {
                togglePlayPause()
                scheduleAutoHide()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "暂停" : "播放")

            Button {
                coordinator.skip(interval: 15)
                scheduleAutoHide()
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("快进 15 秒")
        }
    }

    private var bottomBar: some View {
        let total = max(TimeInterval(coordinator.timemodel.totalTime), 1)
        let displayCurrent = sliderSeekTarget ?? TimeInterval(coordinator.timemodel.currentTime)
        return HStack(spacing: 10) {
            Text(Self.formatTime(displayCurrent))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)

            Slider(
                value: Binding(
                    get: { displayCurrent },
                    set: { sliderSeekTarget = $0 }
                ),
                in: 0...total,
                onEditingChanged: { editing in
                    if editing {
                        hideControlsTask?.cancel()
                    } else if let target = sliderSeekTarget {
                        coordinator.seek(time: target)
                        sliderSeekTarget = nil
                        scheduleAutoHide()
                    }
                }
            )
            .tint(.white)

            Text(Self.formatTime(TimeInterval(coordinator.timemodel.totalTime)))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)

            // 倍速 menu
            playbackRateMenu
        }
    }

    private var playbackRateMenu: some View {
        Menu {
            ForEach(Self.playbackRates, id: \.self) { rate in
                Button {
                    coordinator.playbackRate = rate
                    savedPlaybackRate = rate
                } label: {
                    HStack {
                        Text(Self.formatRate(rate))
                        Spacer()
                        if abs(coordinator.playbackRate - rate) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(Self.formatRate(coordinator.playbackRate))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 38)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var boostHint: some View {
        VStack {
            HStack {
                Spacer()
                Label(Self.formatRate(effectiveBoostRate), systemImage: "forward.fill")
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
        coordinator.playbackRate = effectiveBoostRate
        withAnimation(.easeInOut(duration: 0.15)) { isBoosted = true }
    }

    private func endBoost() {
        guard isBoosted else { return }
        coordinator.playbackRate = savedPlaybackRate
        withAnimation(.easeInOut(duration: 0.15)) { isBoosted = false }
    }

    /// Boost 倍速从 `long_press_speed_times` setting 读；防御性 clamp 到 [1.0, 3.0]
    /// 避免外部异常值（默认 2.0；slider 上限 3.0）。
    private var effectiveBoostRate: Float {
        let v = Float(storedBoostPlaybackRate)
        return min(max(v, 1.0), 3.0)
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

    static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    static func formatRate(_ rate: Float) -> String {
        if abs(rate - rate.rounded()) < 0.01 {
            return String(format: "%.0fx", rate)
        }
        return String(format: "%.2gx", rate)
    }

    private static let playbackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

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

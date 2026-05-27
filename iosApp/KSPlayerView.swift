import SwiftUI
import KSPlayer
import Han1meShared
import SwiftUI
import UIKit

/// SwiftUI 包装 KSPlayer 的底层 `KSVideoPlayer`（仅显示视频内容，无内置 UI），控件层完全
/// 自己拼装但都通过 `KSVideoPlayer.Coordinator` 的 **public API** 操作（`seek(time:)` /
/// `skip(interval:)` / `playbackRate` / `isScaleAspectFill` / `playbackVolume` /
/// `state.isPlaying` / `timemodel.currentTime/totalTime`），所以播放/暂停/倍速/aspect
/// mode/进度都跟 KSPlayer 内部完全同步。
///
/// 不用上游 `KSVideoPlayerView` 的原因：它内部带 `.preferredColorScheme(.dark)` 这是
/// SwiftUI PreferenceKey，会一直 propagate 到 root window，**嵌套 NavigationStack 不能
/// 隔离**，会让外层整个 app 进入 dark mode。`KSVideoPlayerViewBuilder` 是 internal enum
/// 也用不了。
///
/// 通过 `@Binding isFullscreen` / `@Binding isCollapsed` 让外部容器（VideoDetailView）
/// 控制 player 形态。**关键**：始终在 SwiftUI view tree 同一位置，仅靠外层 frame 切换大小,
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
    /// Tracks whether KSPlayer has already applied `KSOptions.startPlayTime`
    /// (i.e. the player's current time has reached the saved resume
    /// position). Until that happens we MUST NOT forward onPlay current
    /// values to onProgress, otherwise the early-stage 0–few-second ticks
    /// (which fire BEFORE startPlayTime is applied) would overwrite the
    /// saved value in the watch-history db with a small number — losing
    /// resume on the next entry. Once the player jumps to ≥ savedSeconds
    /// - 2s we flip this and resume normal persistence.
    @State private var hasReachedStartPlayTime = false
    /// 长按 boost 倍速。读 `long_press_speed_times` —— `PreferencesStore` 已经预留
    /// 这个 key（KMP 端 `IosPreferencesStorage` 用 NSUserDefaults，所以 Swift
    /// `@AppStorage` 直接读到同一份值）。Settings 现在把"长按倍速"绑定到这个 key。
    @AppStorage("long_press_speed_times") private var storedBoostPlaybackRate: Double = 2.0

    // MARK: - Slider state
    /// 进度条本地值。**plain @State**(不是 closure-based binding)，避免 SwiftUI Slider
    /// 第一次拖动时 binding source 没及时更新导致 thumb 跳回原位的问题。
    /// 通过 `.onReceive(coordinator.timemodel.$currentTime)` 同步外部时间，但
    /// 仅在非 dragging 状态下覆盖，避免拖动时被 +1s/s 的播放进度抢走。
    @State private var sliderValue: TimeInterval = 0
    @State private var isSliderEditing = false

    // MARK: - Swipe gesture state
    @State private var dragState: DragKind = .none
    @State private var dragStartProgressSeconds: TimeInterval = 0
    @State private var dragTargetProgressSeconds: TimeInterval = 0
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragCurrentBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0
    @State private var dragCurrentVolume: Float = 0
    /// 长按 timer。finger 落下后启动；移动 > 12pt 或 finger 抬起时 cancel。
    @State private var longPressTask: Task<Void, Never>?
    /// 当前手势是否已经决定走 swipe 路径（以避免长按 timer 重复 schedule）。
    @State private var hasMovedToSwipe = false

    private enum DragKind: Equatable {
        case none
        /// 左右滑：调整播放进度（松手后 commit seek）
        case seek
        /// 左半屏上下滑：屏幕亮度
        case brightness
        /// 右半屏上下滑：播放器音量
        case volume
    }

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

        // GeometryReader wraps KSVideoPlayer (alone, not the whole ZStack) so the
        // DragGesture handler can see the player's own size — needed to decide
        // whether a vertical swipe started on the LEFT half (brightness) or the
        // RIGHT half (volume), and to scale a horizontal swipe to a sensible
        // seek delta. KSVideoPlayer is the only child of this GeometryReader,
        // no branching, so view identity is preserved.
        ZStack {
            GeometryReader { proxy in
                KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                    .onPlay { current, _ in
                        // Don't persist progress until KSPlayer has actually
                        // applied KSOptions.startPlayTime. Until that
                        // happens the player still reports `current`
                        // climbing from 0; writing those small values would
                        // clobber the saved resume position. We detect the
                        // jump by waiting for current to come within 2s of
                        // savedSeconds (i.e. the seek has just landed).
                        guard current.isFinite, current >= 0 else { return }
                        let savedSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
                        if savedSeconds > 5, !hasReachedStartPlayTime {
                            if current >= savedSeconds - 2 {
                                hasReachedStartPlayTime = true
                            } else {
                                return
                            }
                        }
                        if current >= 2.0 {
                            onProgress(current)
                        }
                    }
                    .onFinish { _, _ in onPlaybackEnded() }
                    .onStateChanged { _, state in
                        isPlaying = state.isPlaying
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
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
                    // ONE DragGesture handles BOTH long-press boost and swipe
                    // (brightness/volume/seek). minimumDistance: 0 means we get
                    // an onChanged on every touch-down so we can start a 0.4s
                    // long-press timer; if the finger then moves > 12pt we
                    // cancel the timer and switch to swipe handling. onEnded
                    // ALWAYS endBoosts — fixes the case where boost wasn't
                    // releasing because .onLongPressGesture(pressing:) doesn't
                    // reliably fire pressing(false) when composed with other
                    // simultaneous gestures.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handlePressOrSwipe(value, in: proxy.size)
                            }
                            .onEnded { _ in
                                handlePressOrSwipeEnded()
                            }
                    )
            }

            if isBoosted {
                boostHint.transition(.opacity)
            }

            if dragState != .none {
                swipeHUD.transition(.opacity)
            }

            if showsControls {
                controlsOverlay.transition(.opacity)
            }
        }
        .onAppear {
            scheduleAutoHide()
            // Mount the hidden MPVolumeView so swipe-volume can write the
            // system output volume. Released on disappear so iOS's own
            // volume HUD works everywhere else in the app.
            SystemVolumeController.acquire()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            SystemVolumeController.release()
            // Pause the player when this view is no longer on-screen.
            // Necessary because pushing another VideoDetailView (e.g. via a
            // related-video tap) keeps the previous player alive in the
            // navigation stack — without an explicit pause, BOTH videos
            // would keep playing audio simultaneously.
            coordinator.playerLayer?.pause()
        }
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
        // Slider value is now a PLAIN @State (not a closure-based binding) so
        // SwiftUI's first drag delta correctly persists into binding source on
        // the same render cycle. External player progress is reflected via
        // .onReceive on coordinator.timemodel.$currentTime, but only when the
        // user isn't actively dragging — otherwise the +1s/s update would
        // immediately snap the thumb back from where the finger is.
        return HStack(spacing: 10) {
            Text(Self.formatTime(sliderValue))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)

            Slider(
                value: $sliderValue,
                in: 0...total,
                onEditingChanged: { editing in
                    if editing {
                        isSliderEditing = true
                        hideControlsTask?.cancel()
                    } else {
                        isSliderEditing = false
                        coordinator.seek(time: sliderValue)
                        scheduleAutoHide()
                    }
                }
            )
            .tint(.white)
            .onReceive(coordinator.timemodel.$currentTime) { newTime in
                guard !isSliderEditing else { return }
                let asTime = TimeInterval(newTime)
                if abs(asTime - sliderValue) > 0.5 {
                    sliderValue = asTime
                }
            }

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

    /// HUD displayed in the centre of the player while a swipe gesture is active.
    /// Shows progress preview / brightness / volume depending on dragState.
    @ViewBuilder
    private var swipeHUD: some View {
        ZStack {
            switch dragState {
            case .seek:
                let total = max(TimeInterval(coordinator.timemodel.totalTime), 1)
                let delta = dragTargetProgressSeconds - dragStartProgressSeconds
                let sign = delta >= 0 ? "+" : "−"
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "forward.fill" : "backward.fill")
                            .font(.title3)
                        Text("\(sign)\(Self.formatTime(abs(delta)))")
                            .font(.title3.monospacedDigit().weight(.semibold))
                    }
                    Text("\(Self.formatTime(dragTargetProgressSeconds)) / \(Self.formatTime(total))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            case .brightness:
                hudBar(systemImage: "sun.max.fill",
                       label: "亮度",
                       value: Float(dragCurrentBrightness))
            case .volume:
                hudBar(systemImage: dragCurrentVolume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                       label: "音量",
                       value: dragCurrentVolume)
            case .none:
                EmptyView()
            }
        }
    }

    private func hudBar(systemImage: String, label: String, value: Float) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(label)
                Spacer(minLength: 0)
                Text("\(Int((value * 100).rounded()))%")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .frame(width: 160)

            ProgressView(value: Double(value), total: 1.0)
                .progressViewStyle(.linear)
                .tint(.white)
                .frame(width: 160)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
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

    /// Unified down/move handler. Called from `DragGesture(minimumDistance: 0)`
    /// so we get an onChanged on every touch-down. First call starts a 0.4s
    /// long-press timer (=> startBoost); subsequent calls cancel that timer
    /// and switch to swipe handling once the finger moves > the threshold.
    private func handlePressOrSwipe(_ value: DragGesture.Value, in size: CGSize) {
        // Reserve the top and bottom edges for iOS system gestures
        // (status bar / Notification Center / Control Center pull-down,
        // home indicator swipe-up). When the touch STARTS in these strips,
        // ignore it entirely so a user dragging Control Center down from
        // the top doesn't accidentally crank the brightness, and a user
        // swiping up from the home indicator to go home doesn't seek.
        // Only meaningful in fullscreen (where the player covers those
        // areas), but harmless in inline.
        let topInset: CGFloat = 50
        let bottomInset: CGFloat = 34
        let startY = value.startLocation.y
        if startY < topInset || startY > size.height - bottomInset {
            return
        }

        // Higher threshold so a slight finger tremor during the long-press
        // boost doesn't accidentally classify as swipe and abort the boost.
        // 36pt ≈ a deliberate finger movement; pixel jitter while holding
        // still is normally far less.
        let swipeThreshold: CGFloat = 36
        let distance = hypot(value.translation.width, value.translation.height)

        // First call (just touched down)? Schedule the long-press boost.
        if longPressTask == nil && !hasMovedToSwipe && dragState == .none && !isBoosted {
            longPressTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled, !hasMovedToSwipe {
                    startBoost()
                }
            }
        }

        // If we're already in a swipe, keep updating it.
        if hasMovedToSwipe {
            handleSwipeChanged(value, in: size)
            return
        }

        // Once the boost is active the user committed to long-press mode;
        // do NOT switch to swipe just because their finger drifted a bit.
        // Boost ends naturally on finger up.
        if isBoosted {
            return
        }

        // Threshold crossed before boost started → it was a swipe gesture
        // all along. Cancel the pending boost timer and start swipe.
        if distance > swipeThreshold {
            longPressTask?.cancel()
            longPressTask = nil
            hasMovedToSwipe = true
            handleSwipeChanged(value, in: size)
        }
    }

    /// Always called on finger-up. Cancels long-press timer; ALWAYS endBoost
    /// (so boost can never get stuck on); commits any in-progress swipe.
    private func handlePressOrSwipeEnded() {
        longPressTask?.cancel()
        longPressTask = nil
        if isBoosted { endBoost() }
        if dragState != .none {
            handleSwipeEnded()
        }
        hasMovedToSwipe = false
    }

    /// First swipe-onChanged call (after the 12pt threshold) decides the kind
    /// based on dominant axis & start location. Subsequent calls update the
    /// active dimension only.
    private func handleSwipeChanged(_ value: DragGesture.Value, in size: CGSize) {
        if dragState == .none {
            // Decide direction: vertical vs horizontal based on dominant axis.
            let dx = value.translation.width
            let dy = value.translation.height
            if abs(dx) > abs(dy) {
                dragState = .seek
                dragStartProgressSeconds = TimeInterval(coordinator.timemodel.currentTime)
                dragTargetProgressSeconds = dragStartProgressSeconds
            } else {
                let onLeftHalf = value.startLocation.x < size.width / 2
                if onLeftHalf {
                    dragState = .brightness
                    dragStartBrightness = UIScreen.main.brightness
                    dragCurrentBrightness = dragStartBrightness
                } else {
                    dragState = .volume
                    dragStartVolume = SystemVolumeController.currentVolume()
                    dragCurrentVolume = dragStartVolume
                }
            }
            // While a swipe is active, do not auto-hide the overlay HUD.
            hideControlsTask?.cancel()
        }

        switch dragState {
        case .seek:
            // Map horizontal drag to a seek delta. Full screen-width swipe
            // covers ~50% of the video duration so a meaningful drag travels
            // a usable amount without becoming jittery on long videos.
            let total = TimeInterval(coordinator.timemodel.totalTime)
            guard total > 0, size.width > 0 else { return }
            let fraction = value.translation.width / size.width
            let secondsDelta = TimeInterval(fraction) * total * 0.5
            dragTargetProgressSeconds = max(0, min(total, dragStartProgressSeconds + secondsDelta))
        case .brightness:
            // Up = brighter (negative dy in SwiftUI = upward motion).
            guard size.height > 0 else { return }
            let fraction = -value.translation.height / size.height
            dragCurrentBrightness = max(0, min(1, dragStartBrightness + fraction))
            UIScreen.main.brightness = dragCurrentBrightness
        case .volume:
            // Up = louder. Writes the SYSTEM volume (the same one the hardware
            // buttons control), via the hidden MPVolumeView slider.
            guard size.height > 0 else { return }
            let fraction = -Float(value.translation.height / size.height)
            dragCurrentVolume = max(0, min(1, dragStartVolume + fraction))
            SystemVolumeController.setVolume(dragCurrentVolume)
        case .none:
            break
        }
    }

    private func handleSwipeEnded() {
        if dragState == .seek {
            // Commit the seek only on release; intermediate drag positions
            // were preview-only via the HUD.
            coordinator.seek(time: dragTargetProgressSeconds)
            // Sync slider too so it doesn't snap back to the pre-drag value.
            sliderValue = dragTargetProgressSeconds
        }
        // Hide HUD with a small fade.
        withAnimation(.easeOut(duration: 0.2)) {
            dragState = .none
        }
        scheduleAutoHide()
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

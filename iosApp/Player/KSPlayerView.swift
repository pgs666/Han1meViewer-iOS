import SwiftUI
import KSPlayer
import Han1meShared
import UIKit
import AVFoundation

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
/// 通过 `@Binding isFullscreen` 让外部容器（VideoDetailView）控制 player 形态。
/// **关键**：始终在 SwiftUI view tree 同一位置，仅靠外层 frame 切换大小,
/// view identity 不变 → KSPlayerLayer 复用 → 视频不重新加载，进度不丢失。
@MainActor
struct KSPlayerView: View {
    let snapshot: VideoDetailScreenSnapshot
    @Binding var isFullscreen: Bool
    let onProgress: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void
    /// Optional: invoked whenever the controls overlay shows / hides. Lets
    /// the parent slide the navigation bar in / out together with the
    /// player's HUD so they always animate as one.
    let onControlsVisibilityChanged: (Bool) -> Void
    /// Optional: invoked when the user taps the back button drawn inside
    /// the player's controls overlay. The system back button has been
    /// removed (parent hides the navigation bar entirely), so this is the
    /// player's only way back.
    let onBack: () -> Void
    /// Optional: invoked the first time the underlying media reports a
    /// non-zero natural size. Lets the parent decide whether the video is
    /// landscape or portrait so it can pick the right fullscreen
    /// orientation lock (a portrait video locked to landscape would render
    /// as a tall letterbox between black bars).
    let onNaturalSize: (CGSize) -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @StateObject private var playbackState = KSPlayerPlaybackStateCoordinator()
    @State private var showsControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isBoosted = false
    @State private var savedPlaybackRate: Float = 1.0
    /// User-picked playback source (quality). Nil = use the snapshot's
    /// default-marked source via primarySource(). Wired up from the
    /// quality menu in bottomBar; switching value re-evaluates `body` and
    /// rebuilds KSVideoPlayer with the new url.
    @State private var selectedSourceID: String?
    /// Whether the player should auto-play on entering the detail page,
    /// or wait paused for the user to tap play. Mirrors PreferencesStore's
    /// auto_play_on_enter key (default ON).
    @AppStorage("auto_play_on_enter") private var autoPlayOnEnter: Bool = true
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
    @State private var dragState: KSPlayerDragKind = .none
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
    /// 双指 pinch 进行中。SwiftUI 在多指环境下可能让 single-finger DragGesture(0)
    /// 也 fire onChanged 但**不 fire onEnded**（被 MagnificationGesture 抢走），
    /// 导致 longPress timer 触发 boost 后 endBoost() 永远不调 → boost 卡住。
    /// 这个 flag 让 pinch 一开始就 cancel/退出 boost，并且 timer fire 前 double-check。
    @State private var isPinching = false

    // MARK: - Hardware volume key feedback
    /// SystemVolumeController suppresses iOS's own volume HUD while the
    /// player is on screen — without a replacement, hardware volume key
    /// presses would have no visible feedback. This observer + HUD pair
    /// fills that gap: KVO on AVAudioSession.outputVolume fires whenever
    /// the system volume changes, and we show our own bar (skipping the
    /// case where the change came from our own swipe-volume gesture,
    /// which already shows the same bar via swipeHUD).
    @StateObject private var volumeObserver = SystemVolumeObserver()
    @State private var physicalVolumeHUDActive = false
    @State private var physicalVolumeHUDHideTask: Task<Void, Never>?

    // MARK: - Buffering / loading feedback
    /// Observes the underlying AVPlayer's `timeControlStatus` — the
    /// canonical AVFoundation signal for "is the player currently
    /// buffering / loading?". This drives the loading HUD instead of
    /// trying to derive it from KSPlayerState transitions, which were
    /// fragile across navigation re-mounts (HUD stuck on after popping
    /// back from a tag/artist sub-page).
    @StateObject private var statusObserver = AVPlayerStatusObserver()
    @StateObject private var networkSpeedSampler = KSPlayerNetworkSpeedSampler()
    @State private var currentSpeedText: String?
    @State private var speedSampleTask: Task<Void, Never>?

    init(
        snapshot: VideoDetailScreenSnapshot,
        isFullscreen: Binding<Bool>,
        onProgress: @escaping (TimeInterval) -> Void = { _ in },
        onPlaybackEnded: @escaping () -> Void = {},
        onControlsVisibilityChanged: @escaping (Bool) -> Void = { _ in },
        onBack: @escaping () -> Void = {},
        onNaturalSize: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self._isFullscreen = isFullscreen
        self.onProgress = onProgress
        self.onPlaybackEnded = onPlaybackEnded
        self.onControlsVisibilityChanged = onControlsVisibilityChanged
        self.onBack = onBack
        self.onNaturalSize = onNaturalSize
    }

    var body: some View {
        let _ = Self.configureKSPlayerGlobalsOnce
        Group {
            if let activeSource = activeSource,
               let url = URL(string: activeSource.url) {
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
        let options = KSPlayerOptionsFactory.make(
            resumeSeconds: resumeSeconds,
            autoPlayOnEnter: autoPlayOnEnter
        )

        // GeometryReader wraps KSVideoPlayer (alone, not the whole ZStack) so the
        // DragGesture handler can see the player's own size — needed to decide
        // whether a vertical swipe started on the LEFT half (brightness) or the
        // RIGHT half (volume), and to scale a horizontal swipe to a sensible
        // seek delta. KSVideoPlayer is the only child of this GeometryReader,
        // no branching, so view identity is preserved.
        ZStack {
            GeometryReader { proxy in
                KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                    .onPlay { current, total in
                        handlePlaybackProgress(current: current, total: total)
                    }
                    .onFinish { _, _ in onPlaybackEnded() }
                    .onStateChanged { layer, state in
                        handlePlayerState(layer: layer, state: state, url: url)
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
                    .modifier(
                        KSPlayerGestureModifier(
                            onDoubleTap: handleDoubleTap,
                            onSingleTap: handleSingleTap,
                            onPinchChanged: handlePinchChanged,
                            onPinchEnded: handlePinchEnded,
                            onDragChanged: { handlePressOrSwipe($0, in: proxy.size) },
                            onDragEnded: handlePressOrSwipeEnded
                        )
                    )
            }

            // Z-order: KSVideoPlayer < controlsOverlay < swipeHUD / boostHint.
            // The two HUDs sit ABOVE the controls so the centre play / skip
            // buttons (which live inside controlsOverlay) don't visually
            // cover the swipe HUD or the boost badge.
            if showsControls {
                controlsOverlay.transition(.opacity)
            }

            if dragState != .none {
                swipeHUD.transition(.opacity)
            }

            if isBoosted {
                boostHint.transition(.opacity)
            }

            if statusObserver.isWaitingForPlayback {
                loadingHUD.transition(.opacity)
            }

            if physicalVolumeHUDActive {
                physicalVolumeHUD.transition(.opacity)
            }
        }
        .modifier(
            KSPlayerLifecycleModifier(
                volumeObserver: volumeObserver,
                isWaitingForPlayback: statusObserver.isWaitingForPlayback,
                onAppear: handlePlayerAppear,
                onDisappear: handlePlayerDisappear,
                onWaitingChanged: handleWaitingChanged,
                onPhysicalVolumeChanged: handlePhysicalVolumeChanged
            )
        )
    }

    // MARK: - Playback coordination

    private func handlePlaybackProgress(current: TimeInterval, total: TimeInterval) {
        playbackState.handleProgress(
            current: current,
            total: total,
            savedSeconds: TimeInterval(snapshot.playbackPositionMillis) / 1000,
            player: coordinator,
            onProgress: onProgress
        )
    }

    private func handlePlayerState(layer: KSPlayerLayer, state: KSPlayerState, url: URL) {
        playbackState.handleState(
            layer: layer,
            state: state,
            url: url,
            autoPlay: autoPlayOnEnter,
            onNaturalSize: onNaturalSize
        )
        statusObserver.observe(networkSpeedSampler.avPlayer(from: layer.player))
    }

    // MARK: - Gesture coordination

    private func handleDoubleTap() {
        if isBoosted { endBoost() }
        togglePlayPause()
        scheduleAutoHide()
    }

    private func handleSingleTap() {
        if isBoosted { endBoost() }
        withAnimation(.easeInOut(duration: 0.18)) { showsControls.toggle() }
        AppLogger.log("gesture: tap controls=\(showsControls ? "show" : "hide")")
        onControlsVisibilityChanged(showsControls)
        if showsControls { scheduleAutoHide() }
    }

    private func handlePinchChanged() {
        isPinching = true
        longPressTask?.cancel()
        longPressTask = nil
        if isBoosted { endBoost() }
    }

    private func handlePinchEnded(_ value: CGFloat) {
        isPinching = false
        if isBoosted { endBoost() }
        if !isFullscreen, value > 1.15 {
            AppLogger.log("gesture: pinch fullscreen=on")
            withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = true }
        } else if isFullscreen, value < 0.85 {
            AppLogger.log("gesture: pinch fullscreen=off")
            withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = false }
        }
    }

    // MARK: - Player lifecycle

    private func handlePlayerAppear() {
        scheduleAutoHide()
        SystemVolumeController.acquire()
        volumeObserver.start()
        playbackState.resetForMount()
        networkSpeedSampler.reset()
        currentSpeedText = nil
        statusObserver.observe(networkSpeedSampler.avPlayer(from: coordinator.playerLayer?.player))
        AppLogger.log("player mount autoPlayOnEnter=\(autoPlayOnEnter) ksAutoPlay=\(KSOptions.isAutoPlay)")
    }

    private func handlePlayerDisappear() {
        hideControlsTask?.cancel()
        SystemVolumeController.release()
        volumeObserver.stop()
        physicalVolumeHUDHideTask?.cancel()
        physicalVolumeHUDHideTask = nil
        speedSampleTask?.cancel()
        speedSampleTask = nil
        coordinator.playerLayer?.pause()
    }

    private func handleWaitingChanged(_ waiting: Bool) {
        if waiting {
            startSpeedSampling()
        } else {
            speedSampleTask?.cancel()
            speedSampleTask = nil
            currentSpeedText = nil
        }
    }

    private func handlePhysicalVolumeChanged() {
        guard dragState != .volume else { return }
        physicalVolumeHUDActive = true
        physicalVolumeHUDHideTask?.cancel()
        physicalVolumeHUDHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                physicalVolumeHUDActive = false
            }
        }
    }

    // MARK: - Loading / volume HUDs

    private var loadingHUD: some View {
        KSPlayerLoadingHUD(speedText: currentSpeedText)
    }

    private var physicalVolumeHUD: some View {
        KSPlayerValueHUD(
            systemImage: volumeObserver.outputVolume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill",
            label: "音量",
            value: volumeObserver.outputVolume
        )
    }

    // MARK: - Network speed sampling

    private func startSpeedSampling() {
        speedSampleTask?.cancel()
        speedSampleTask = Task { @MainActor in
            while !Task.isCancelled {
                currentSpeedText = networkSpeedSampler.sample(
                    player: coordinator.playerLayer?.player
                )
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private var controlsOverlay: some View {
        KSPlayerControlsOverlay(
            title: snapshot.title,
            playbackSources: snapshot.playbackSources,
            activeSource: activeSource,
            coordinator: coordinator,
            isFullscreen: $isFullscreen,
            isPlaying: playbackState.isPlaying,
            sliderValue: $sliderValue,
            isSliderEditing: $isSliderEditing,
            selectedSourceID: $selectedSourceID,
            savedPlaybackRate: $savedPlaybackRate,
            onBack: onBack,
            onTogglePlayPause: togglePlayPause,
            onCancelAutoHide: { hideControlsTask?.cancel() },
            onScheduleAutoHide: scheduleAutoHide
        )
    }

    private var boostHint: some View {
        KSPlayerBoostHint(rate: effectiveBoostRate)
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
                KSPlayerSeekHUD(delta: delta, target: dragTargetProgressSeconds, total: total)
            case .brightness:
                KSPlayerValueHUD(
                    systemImage: "sun.max.fill",
                    label: "亮度",
                    value: Float(dragCurrentBrightness)
                )
            case .volume:
                KSPlayerValueHUD(
                    systemImage: dragCurrentVolume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: "音量",
                    value: dragCurrentVolume
                )
            case .none:
                EmptyView()
            }
        }
    }

    private var emptyPlaceholder: some View {
        KSPlayerEmptyPlaceholder()
    }

    // MARK: - Helpers

    private func primarySource() -> VideoPlaybackSourceRow? {
        snapshot.playbackSources.first(where: { $0.isDefault }) ?? snapshot.playbackSources.first
    }

    /// The source currently being played: user-picked one if set, else
    /// the snapshot's default source. Used both as the URL provider for
    /// KSVideoPlayer and as the indicator-checkmark target in the
    /// quality menu.
    private var activeSource: VideoPlaybackSourceRow? {
        if let id = selectedSourceID,
           let picked = snapshot.playbackSources.first(where: { $0.id == id }) {
            return picked
        }
        return primarySource()
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
        // Also reserve the left and right edges so a user starting a
        // swipe-to-go-back gesture (iOS UINavigationController interactive
        // pop) along the left edge doesn't get hijacked into a horizontal
        // seek. The right inset mirrors this for symmetry and to leave
        // room for any future system right-edge gesture.
        let leftInset: CGFloat = 24
        let rightInset: CGFloat = 24
        let startY = value.startLocation.y
        let startX = value.startLocation.x
        if startY < topInset || startY > size.height - bottomInset {
            return
        }
        if startX < leftInset || startX > size.width - rightInset {
            return
        }

        // Higher threshold so a slight finger tremor during the long-press
        // boost doesn't accidentally classify as swipe and abort the boost.
        // 36pt ≈ a deliberate finger movement; pixel jitter while holding
        // still is normally far less.
        let swipeThreshold: CGFloat = 36
        let distance = hypot(value.translation.width, value.translation.height)

        // First call (just touched down)? Schedule the long-press boost.
        // Skip if a pinch is already in progress: SwiftUI may have routed
        // the touch-down to DragGesture(0) on a multi-finger gesture; we
        // don't want long-press to fire under those conditions.
        if longPressTask == nil && !hasMovedToSwipe && dragState == .none && !isBoosted && !isPinching {
            longPressTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled, !hasMovedToSwipe, !isPinching {
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
        AppLogger.log("gesture: toggle play/pause was=\(playbackState.isPlaying ? "playing" : "paused")")
        if playbackState.isPlaying { layer.pause() } else { layer.play() }
    }

    private func startBoost() {
        guard !isBoosted else { return }
        savedPlaybackRate = coordinator.playbackRate
        coordinator.playbackRate = effectiveBoostRate
        AppLogger.log("gesture: long-press boost start x\(effectiveBoostRate)")
        withAnimation(.easeInOut(duration: 0.15)) { isBoosted = true }
    }

    private func endBoost() {
        guard isBoosted else { return }
        coordinator.playbackRate = savedPlaybackRate
        AppLogger.log("gesture: long-press boost end")
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
            onControlsVisibilityChanged(false)
        }
    }

    /// KSPlayer 一次性全局配置：自动播放 + 后台音频会话（解决审计 P0-L1 的一半）。
    private static let configureKSPlayerGlobalsOnce: Void = {
        KSOptions.isAutoPlay = true
        KSOptions.setAudioSession()
    }()
}

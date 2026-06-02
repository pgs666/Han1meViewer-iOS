import SwiftUI
import KSPlayer
import Han1meShared
import SwiftUI
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
    /// Optional: invoked whenever the player's playing/paused state flips.
    /// Used by the parent to decide whether to allow scroll-driven shrink
    /// of the player area (only paused state shrinks).
    let onPlayingChanged: (Bool) -> Void
    /// Optional: invoked whenever the controls overlay shows / hides. Lets
    /// the parent slide the navigation bar in / out together with the
    /// player's HUD so they always animate as one.
    let onControlsVisibilityChanged: (Bool) -> Void
    /// Optional: invoked when the user taps the back button drawn inside
    /// the player's controls overlay. The system back button has been
    /// removed (parent hides the navigation bar entirely), so this is the
    /// player's only way back.
    let onBack: () -> Void
    /// True when the parent has shrunk the player below its 16:9 size via
    /// the follow-finger collapse (paused + scrolled). When this is true,
    /// a single tap on the video does NOT toggle the controls overlay —
    /// it instead asks the parent to expand the player back to 16:9. This
    /// is the user-requested workaround for the visible "video + controls
    /// pulse" that occurred when the controls overlay materialised on
    /// top of a shrunken player.
    let isShrunken: Bool
    /// Tap handler invoked when the user taps a shrunken player; parent is
    /// expected to expand the player back to its full size.
    let onRequestExpand: () -> Void
    /// Optional: invoked the first time the underlying media reports a
    /// non-zero natural size. Lets the parent decide whether the video is
    /// landscape or portrait so it can pick the right fullscreen
    /// orientation lock (a portrait video locked to landscape would render
    /// as a tall letterbox between black bars).
    let onNaturalSize: (CGSize) -> Void

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
    /// Whether we've already manually seeked to the saved resume position
    /// once the real video duration is known. KSPlayer's built-in
    /// `KSOptions.startPlayTime` mechanism sometimes runs BEFORE the
    /// player has the actual `totalTime` (it briefly defaults to 1s),
    /// so the seek silently no-ops and the video starts from 0. We
    /// retry the seek ourselves the first time onPlay reports a real
    /// totalTime (> 1.5s), guaranteeing resume even if startPlayTime fails.
    @State private var hasAppliedResumeSeek = false
    /// Whether `onNaturalSize` has been fired already. We only want to
    /// notify the parent once — the natural size won't change mid-playback.
    @State private var naturalSizeReported = false
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
    @State private var dragState: DragKind = .none
    @State private var dragStartProgressSeconds: TimeInterval = 0
    @State private var dragTargetProgressSeconds: TimeInterval = 0
    @State private var dragStartBrightness: CGFloat = 0
    @State private var dragCurrentBrightness: CGFloat = 0
    @State private var dragStartVolume: Float = 0
    @State private var dragCurrentVolume: Float = 0
    @GestureState private var isPlayerDragGestureActive = false
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
    @State private var physicalVolumeHUDGeneration: UInt64 = 0
    @State private var lastHandledPhysicalVolumeTick: UInt64 = 0
    @State private var suppressPhysicalVolumeHUDUntil = Date.distantPast

    // MARK: - Buffering / loading feedback
    /// Observes the underlying AVPlayer's `timeControlStatus` — the
    /// canonical AVFoundation signal for "is the player currently
    /// buffering / loading?". This drives the loading HUD instead of
    /// trying to derive it from KSPlayerState transitions, which were
    /// fragile across navigation re-mounts (HUD stuck on after popping
    /// back from a tag/artist sub-page).
    @StateObject private var statusObserver = AVPlayerStatusObserver()
    @State private var currentSpeedText: String?
    @State private var speedSampleTask: Task<Void, Never>?
    /// Previous loadedTimeRanges-end and wall-clock timestamp, used to
    /// synthesise speed from buffer-fill rate × track bitrate when
    /// AVPlayerItem.accessLog is nil (typical for progressive mp4 where
    /// AVFoundation does not generate access-log events).
    @State private var lastLoadedEnd: Double = 0
    @State private var lastSampleAt: Date?

    /// Belt-and-braces enforcement of the autoPlayOnEnter preference,
    /// fired exactly once on the first transition into `.bufferFinished`.
    /// KSOptions.isAutoPlay is honoured inconsistently across KSPlayer
    /// versions: in some configurations the layer reaches bufferFinished
    /// but never starts playing, in others it would play even when off.
    /// We intervene once with the user-intended action (play or pause)
    /// and then leave manual control to the user.
    @State private var autoPlayApplied = false
    /// Caps onStateChanged log spam to the first few transitions per view
    /// mount, so we can see what KSPlayer actually does without burying
    /// the rest of AppLogger output.
    @State private var stateLogBudget: Int = 0

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
        onPlaybackEnded: @escaping () -> Void = {},
        onPlayingChanged: @escaping (Bool) -> Void = { _ in },
        onControlsVisibilityChanged: @escaping (Bool) -> Void = { _ in },
        onBack: @escaping () -> Void = {},
        isShrunken: Bool = false,
        onRequestExpand: @escaping () -> Void = {},
        onNaturalSize: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self._isFullscreen = isFullscreen
        self._isCollapsed = isCollapsed
        self.onProgress = onProgress
        self.onPlaybackEnded = onPlaybackEnded
        self.onPlayingChanged = onPlayingChanged
        self.onControlsVisibilityChanged = onControlsVisibilityChanged
        self.onBack = onBack
        self.isShrunken = isShrunken
        self.onRequestExpand = onRequestExpand
        self.onNaturalSize = onNaturalSize
    }

    var body: some View {
        let _ = Self.configureKSPlayerGlobalsOnce
        Group {
            if isCollapsed {
                collapsedStrip
            } else if let activeSource = activeSource,
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
                    .onPlay { current, total in
                        guard current.isFinite, current >= 0 else { return }
                        let savedSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000

                        // STEP 1: Manual resume-seek fallback. KSPlayer's
                        // built-in KSOptions.startPlayTime can be applied
                        // BEFORE the real video duration is known (totalTime
                        // briefly defaults to 1s), causing the seek to
                        // silently no-op. As soon as we see a real totalTime
                        // here, retry the seek ourselves. Race-safe: gated
                        // by hasAppliedResumeSeek so we only do this once.
                        if savedSeconds > 1, !hasAppliedResumeSeek, total > 1.5 {
                            coordinator.seek(time: savedSeconds)
                            hasAppliedResumeSeek = true
                            // Don't write progress this round — the seek is
                            // in flight; current is still pre-seek.
                            return
                        }

                        // STEP 2: Block onPlay writes until the seek has
                        // actually landed (current near savedSeconds).
                        // Prevents early-stage 0..few-second ticks from
                        // clobbering the saved value in the watch-history db.
                        if savedSeconds > 5, !hasReachedStartPlayTime {
                            if current >= savedSeconds - 2 {
                                hasReachedStartPlayTime = true
                            } else {
                                return
                            }
                        }

                        // Forward every post-startup tick to onProgress —
                        // including current=0 (user dragged the slider all
                        // the way back). The earlier `current >= 2.0` guard
                        // was there to silence KSPlayer's startup-phantom
                        // zeros, but those are already filtered out upstream
                        // by the hasAppliedResumeSeek / hasReachedStartPlayTime
                        // gates above. With the guard in place a deliberate
                        // user rewind to 0 (or below ~2s) silently failed to
                        // persist, so the saved resume position kept its
                        // previous value across re-entry.
                        onProgress(current)
                    }
                    .onFinish { _, _ in onPlaybackEnded() }
                    .onStateChanged { layer, state in
                        // DIAGNOSTIC: the player previously swallowed every
                        // state, so a failed open showed only a black screen
                        // with no clue. Log the error state (and the URL /
                        // whether it's a local file) so we can see WHY a
                        // downloaded file won't play. Not a fix — pure signal.
                        if state == .error {
                            AppLogger.log("player error state url=\(url.absoluteString) isFile=\(url.isFileURL) state=\(state)")
                        }
                        if stateLogBudget > 0 {
                            stateLogBudget -= 1
                            AppLogger.log("player state=\(state) isPlaying=\(state.isPlaying)")
                        }
                        // Belt-and-braces enforcement of the autoplay
                        // preference. Fire once on the first .bufferFinished
                        // — by that point the player is fully ready and
                        // honours play()/pause() reliably.
                        //
                        // CRITICAL: set the flag BEFORE calling play()/
                        // pause(). KSPlayerLayer.play() ends with
                        //   state = ... ? .bufferFinished : .buffering
                        // whose willSet re-enters this very closure
                        // synchronously through the delegate. If the flag
                        // is set after, the recursive call sees it false
                        // and calls play() again — unbounded recursion
                        // until the stack guard kills the process.
                        if !autoPlayApplied, state == .bufferFinished {
                            autoPlayApplied = true
                            AppLogger.log("autoplay enforced: \(autoPlayOnEnter ? "play" : "pause")")
                            if autoPlayOnEnter {
                                layer.play()
                            } else {
                                layer.pause()
                            }
                        }
                        let nowPlaying = state.isPlaying
                        if nowPlaying != isPlaying {
                            isPlaying = nowPlaying
                            onPlayingChanged(nowPlaying)
                        }
                        // Wire / re-wire the timeControlStatus observer
                        // any time KSPlayer's state ticks, so we always have
                        // the up-to-date AVPlayer reference (it can be
                        // recreated when the URL or codec changes).
                        statusObserver.observe(Self.findAVPlayer(in: layer.player))
                        if !naturalSizeReported {
                            let size = layer.player.naturalSize
                            if size.width > 0 && size.height > 0 {
                                naturalSizeReported = true
                                onNaturalSize(size)
                            }
                        }
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
                        // Safety: any tap should clear stuck boost (covers
                        // the rare race where DragGesture's onEnded was
                        // swallowed by MagnificationGesture and boost is
                        // still on). Cheap, side-effect-free if not boosted.
                        if isBoosted { endBoost() }
                        togglePlayPause()
                        scheduleAutoHide()
                    }
                    .onTapGesture(count: 1) {
                        if isBoosted { endBoost() }
                        if isShrunken {
                            // Player is currently shrunk by scroll. First
                            // tap restores it to 16:9 instead of opening the
                            // controls — avoids the visible layout pulse
                            // that would otherwise happen when the controls
                            // overlay tries to materialise on top of a
                            // mid-collapse-animation player.
                            onRequestExpand()
                            return
                        }
                        withAnimation(.easeInOut(duration: 0.18)) { showsControls.toggle() }
                        AppLogger.log("gesture: tap controls=\(showsControls ? "show" : "hide")")
                        onControlsVisibilityChanged(showsControls)
                        if showsControls { scheduleAutoHide() }
                    }
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { _ in
                                // The user is pinching → cancel any pending
                                // long-press timer and abort an active boost.
                                // Without this the long-press timer would
                                // still fire mid-pinch (DragGesture(0) had
                                // already touched-down) and lock boost on,
                                // because the corresponding DragGesture
                                // .onEnded gets eaten by SwiftUI's multi-
                                // touch arbitration with the pinch.
                                isPinching = true
                                longPressTask?.cancel()
                                longPressTask = nil
                                resetSwipeHUDState()
                                if isBoosted { endBoost() }
                            }
                            .onEnded { value in
                                isPinching = false
                                // Final defensive cleanup in case state slipped through.
                                if isBoosted { endBoost() }
                                if !isFullscreen, value > 1.15 {
                                    AppLogger.log("gesture: pinch fullscreen=on")
                                    withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = true }
                                } else if isFullscreen, value < 0.85 {
                                    AppLogger.log("gesture: pinch fullscreen=off")
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
                    //
                    // Edge handling: the left/right deadzone lives inside
                    // handlePressOrSwipe (touches starting in the outer 24pt are
                    // ignored for seek). This gesture stays attached to the
                    // video view itself — NOT a separate hittable overlay —
                    // otherwise the overlay would sit above the video and steal
                    // the tap / double-tap / pinch gestures.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($isPlayerDragGestureActive) { _, isActive, _ in
                                isActive = true
                            }
                            .onChanged { value in
                                handlePressOrSwipe(value, in: proxy.size)
                            }
                            .onEnded { _ in
                                handlePressOrSwipeEnded()
                            }
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
        .onAppear {
            scheduleAutoHide()
            physicalVolumeHUDActive = false
            resetSwipeHUDState()
            // Mount the hidden MPVolumeView so swipe-volume can write the
            // system output volume. Released on disappear so iOS's own
            // volume HUD works everywhere else in the app.
            SystemVolumeController.acquire()
            volumeObserver.start()
            // Reset per-mount autoplay/log-budget state. Loading state is
            // now derived from AVPlayer.timeControlStatus so we don't
            // need to seed it manually here.
            autoPlayApplied = false
            stateLogBudget = 8
            lastLoadedEnd = 0
            lastSampleAt = nil
            currentSpeedText = nil
            // Bind the status observer eagerly if a layer already exists
            // (re-appear after navigation pop); fresh mounts will pick
            // it up via the onStateChanged callback once the layer is
            // created.
            statusObserver.observe(Self.findAVPlayer(in: coordinator.playerLayer?.player))
            AppLogger.log("player mount autoPlayOnEnter=\(autoPlayOnEnter) ksLoadAutoPlay=\(KSOptions.isAutoPlay)")
        }
        .onDisappear {
            hideControlsTask?.cancel()
            SystemVolumeController.release()
            volumeObserver.stop()
            physicalVolumeHUDGeneration &+= 1
            physicalVolumeHUDActive = false
            resetSwipeHUDState()
            speedSampleTask?.cancel()
            speedSampleTask = nil
            // Pause the player when this view is no longer on-screen.
            // Necessary because pushing another VideoDetailView (e.g. via a
            // related-video tap) keeps the previous player alive in the
            // navigation stack — without an explicit pause, BOTH videos
            // would keep playing audio simultaneously.
            coordinator.playerLayer?.pause()
        }
        .onValueChange(of: isShrunken) { newValue in
            // The moment the parent reports the player has begun shrinking
            // (paused user starts scrolling content up), hide the controls
            // overlay. Otherwise the HUD would persist over a steadily
            // shrinking player and look stuck / out-of-sync.
            guard newValue, showsControls else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                showsControls = false
            }
            onControlsVisibilityChanged(false)
            hideControlsTask?.cancel()
        }
        .onValueChange(of: isPlayerDragGestureActive) { isActive in
            guard !isActive else { return }
            let shouldResumeAutoHide = hasMovedToSwipe || dragState != .none || isBoosted
            resetSwipeHUDState()
            if shouldResumeAutoHide {
                scheduleAutoHide()
            }
        }
        .onValueChange(of: statusObserver.isWaitingForPlayback) { waiting in
            // Speed sampler only runs while the player is genuinely waiting
            // for data. Covers both initial asset-loading (currentItem
            // status .unknown) AND mid-playback rebuffers (tcs ==
            // .waitingToPlayAtSpecifiedRate). When playback settles into
            // .playing or user-explicit .paused, the sampler stops.
            if waiting {
                startSpeedSampling()
            } else {
                speedSampleTask?.cancel()
                speedSampleTask = nil
                currentSpeedText = nil
            }
        }
        .onReceive(volumeObserver.$changeTick) { tick in
            // @Published emits its current value immediately on subscription.
            // Tick 0 is not a hardware-key event; showing HUD for it can keep
            // recreating the hide timer during normal SwiftUI re-subscription.
            guard tick > 0 else { return }
            guard tick != lastHandledPhysicalVolumeTick else { return }
            lastHandledPhysicalVolumeTick = tick
            // Skip if the change came from our swipe-volume gesture —
            // swipeHUD is already visible for that case. Otherwise pop
            // the physical-key HUD and auto-hide after 1.5s.
            guard dragState != .volume else { return }
            guard Date() >= suppressPhysicalVolumeHUDUntil else { return }
            showPhysicalVolumeHUD()
        }
    }

    private func showPhysicalVolumeHUD() {
        physicalVolumeHUDGeneration &+= 1
        let generation = physicalVolumeHUDGeneration
        physicalVolumeHUDActive = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard generation == physicalVolumeHUDGeneration else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                physicalVolumeHUDActive = false
            }
        }
    }

    // MARK: - Loading / volume HUDs

    private var loadingHUD: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.4)
            Text(loadingHUDText)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }

    private var loadingHUDText: String {
        let label = String(localized: "加载中")
        if let speed = currentSpeedText {
            return "\(label) · \(speed)"
        }
        return label
    }

    private var physicalVolumeHUD: some View {
        hudBar(
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
                currentSpeedText = sampleNetworkSpeed()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    /// Reach the underlying AVPlayer through KSPlayer's MediaPlayerProtocol
    /// (KSAVPlayer wraps an AVPlayer; KSMEPlayer/FFmpeg has none) and read
    /// `observedBitrate` from the latest access-log event. Returns nil for
    /// non-AVPlayer backends or when no events are available yet.
    private func sampleNetworkSpeed() -> String? {
        guard let player = coordinator.playerLayer?.player else { return nil }
        guard let avPlayer = Self.findAVPlayer(in: player) else { return nil }
        guard let item = avPlayer.currentItem else { return nil }

        // Path 1: AVPlayerItem.accessLog (works for HLS / network streams
        // AVFoundation chooses to log; usually empty for progressive mp4).
        if let event = item.accessLog()?.events.last {
            let bps = event.observedBitrate
            if bps > 0 {
                return Self.formatSpeed(bytesPerSec: bps / 8.0)
            }
            let bytes = event.numberOfBytesTransferred
            let dur = event.transferDuration
            if bytes > 0, dur > 0 {
                return Self.formatSpeed(bytesPerSec: Double(bytes) / dur)
            }
        }

        // Path 2: synthesise from buffer fill-rate × track bitrate, which
        // works for progressive mp4 where accessLog stays nil.
        return synthesiseSpeed(from: item)
    }

    private func synthesiseSpeed(from item: AVPlayerItem) -> String? {
        let now = Date()
        guard
            let lastRange = item.loadedTimeRanges.last?.timeRangeValue,
            lastRange.duration.isNumeric, lastRange.start.isNumeric
        else { return nil }
        let currentEnd = lastRange.start.seconds + lastRange.duration.seconds

        // Capture previous sample, then update for next call. Defer ensures
        // the update happens regardless of which return path we take.
        let prevEnd = lastLoadedEnd
        let prevTime = lastSampleAt
        lastLoadedEnd = currentEnd
        lastSampleAt = now

        guard let prevTime else { return nil }   // first sample, no delta
        let wallDelta = now.timeIntervalSince(prevTime)
        guard wallDelta > 0.1 else { return nil }
        let bufferDelta = currentEnd - prevEnd
        guard bufferDelta > 0 else {
            // No new buffer this tick — speed is effectively zero, but
            // showing "0 B/s" is misleading for a transient stall.
            return nil
        }
        let fillRate = bufferDelta / wallDelta

        // estimatedDataRate is in bits/sec; comes from the asset metadata
        // and is populated as soon as the track loads (typically before
        // playback can start).
        let bitrate: Float = item.tracks
            .compactMap { $0.assetTrack }
            .first { $0.mediaType == .video }?.estimatedDataRate ?? 0
        guard bitrate > 0 else { return nil }
        let bytesPerSec = Double(bitrate) / 8.0 * fillRate
        return Self.formatSpeed(bytesPerSec: bytesPerSec)
    }

    private static func findAVPlayer(in any: Any, depth: Int = 0) -> AVPlayer? {
        guard depth < 4 else { return nil }
        if let p = any as? AVPlayer { return p }
        let mirror = Mirror(reflecting: any)
        for child in mirror.children {
            if let p = findAVPlayer(in: child.value, depth: depth + 1) { return p }
        }
        return nil
    }

    private static func formatSpeed(bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_000_000)
        }
        if bytesPerSec >= 1_000 {
            return String(format: "%.0f KB/s", bytesPerSec / 1_000)
        }
        return String(format: "%.0f B/s", bytesPerSec)
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
                bottomBar
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
        }
        // Pin to the player ZStack's full extent. Without this, the
        // controls overlay's intrinsic size is indeterminate (LinearGradient
        // + Spacer-padded VStack), and SwiftUI's first layout pass when
        // it appears can briefly inflate the parent ZStack — which the
        // user perceives as "the whole video and controls grow on tap".
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            // Back button — drawn inside the player overlay so it shows /
            // hides together with the rest of the HUD without affecting
            // any system layout. Parent (VideoDetailView) hides the nav
            // bar entirely.
            // Fullscreen: tap exits fullscreen back to inline (does NOT
            // pop the detail page). Inline: tap pops the detail page.
            iconButton(systemImage: "chevron.left", label: isFullscreen ? "退出全屏" : "返回") {
                if isFullscreen {
                    withAnimation(.easeInOut(duration: 0.25)) { isFullscreen = false }
                } else {
                    onBack()
                }
            }
            // Fullscreen: surface video title where the navigation back-button
            // sat. Never shown inline (nav bar still has the back-button +
            // (after caller's change) no inline title).
            if isFullscreen {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Limit so a long title can't grow into the right-side
                    // button cluster.
                    .padding(.leading, 4)
            }
            Spacer(minLength: 8)
            // 静音 toggle
            iconButton(
                systemImage: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: coordinator.isMuted ? "取消静音" : "静音"
            ) {
                coordinator.isMuted.toggle()
            }
            // 收起按钮（暂停 + 非全屏时显示，跟 mute 等并排）
            if !isFullscreen, !isPlaying {
                iconButton(systemImage: "chevron.up", label: "收起播放器") {
                    withAnimation(.easeInOut(duration: 0.25)) { isCollapsed = true }
                }
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
            // Fullscreen toggle has been moved into bottomBar (right of the
            // playback-rate menu) — see `bottomBar`. Keeping the cluster
            // {mute, collapse, aspect} on the right of topBar.
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
            // Play / pause moved here from the (now-removed) centre controls
            // — sits at the left of the progress strip, matching the user's
            // requested layout. Uses iconButton so it inherits the 44pt
            // hit-target rule.
            iconButton(
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "暂停" : "播放"
            ) {
                togglePlayPause()
                scheduleAutoHide()
            }

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
            .onAppear {
                // Sync the slider to the player's current time as soon as
                // bottomBar mounts, so when the user taps to reveal
                // controls the thumb is already in the right place. Without
                // this we'd wait up to 1s for the next timemodel publish.
                if !isSliderEditing {
                    sliderValue = TimeInterval(coordinator.timemodel.currentTime)
                }
            }
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

            // 画质 menu — only shown if the snapshot exposes more than one
            // source (typical: the page only ships a single 'auto' source
            // because the script extraction returns one URL). When more
            // qualities exist they sit between the rate menu and the
            // fullscreen toggle as the user requested.
            if snapshot.playbackSources.count > 1 {
                qualityMenu
            }

            // 全屏 toggle — placed immediately to the right of the playback
            // rate menu per user request. Uses iconButton for the same 44pt
            // hit-target as the other chrome buttons.
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

    private var qualityMenu: some View {
        Menu {
            ForEach(snapshot.playbackSources) { source in
                Button {
                    selectedSourceID = source.id
                } label: {
                    HStack {
                        Text(source.label)
                        Spacer()
                        if activeSource?.id == source.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(activeSource?.label ?? "画质")
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
            // Top-centre so the badge sits above the player content but
            // doesn't collide with the three top-right control buttons
            // (mute / aspect / fullscreen).
            HStack {
                Spacer()
                Label(Self.formatRate(effectiveBoostRate), systemImage: "forward.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.top, 12)
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
                // Outer 44×44 frame is the actual hit-test area — meets
                // Apple's HIG minimum touch-target size while keeping the
                // 36×36 black circle as the visual chrome (the surrounding
                // 4pt ring is transparent). contentShape ensures taps in
                // the transparent ring still register on the button.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
            suppressPhysicalVolumeHUDUntil = Date().addingTimeInterval(0.8)
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

    private func resetSwipeHUDState() {
        longPressTask?.cancel()
        longPressTask = nil
        hasMovedToSwipe = false
        if isBoosted {
            endBoost()
        }
        if dragState != .none {
            withAnimation(.easeOut(duration: 0.18)) {
                dragState = .none
            }
        }
    }

    private func togglePlayPause() {
        guard let layer = coordinator.playerLayer else { return }
        AppLogger.log("gesture: toggle play/pause was=\(isPlaying ? "playing" : "paused")")
        if isPlaying { layer.pause() } else { layer.play() }
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
        // KSPlayer uses this class-level switch to decide whether to begin
        // opening/buffering the URL at all. Keep it ON for loading, then
        // enforce the user's autoPlayOnEnter preference once the layer first
        // reaches .bufferFinished in onStateChanged.
        KSOptions.isAutoPlay = true
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

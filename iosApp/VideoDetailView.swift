import SwiftUI
import UIKit
import Han1meShared

struct VideoDetailView: View {
    let videoCode: String
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    private let tabletLeftMinimumWidth: CGFloat = 620
    private let tabletSidebarMinimumWidth: CGFloat = 360
    private let playerContinuationStripHeight: CGFloat = 56
    private let commentComposerBottomSlack: CGFloat = 96
    @StateObject private var viewModel: VideoDetailViewModel
    @StateObject private var commentViewModel: CommentViewModel
    @State private var pagerState = VideoDetailPagerState()
    @State private var isPlayerFullscreen = false
    @State private var playerPlayRequestToken = 0
    @State private var commentComposeText = ""
    @State private var isCommentInternalOverlayActive = false
    @State private var commentComposerHeight: CGFloat = CommentComposerBar.compactHeight
    @State private var fullscreenOrientationTask: Task<Void, Never>?
    @State private var isFullscreenOrientationLocked = false
    /// Natural size of the loaded video (reported by KSPlayer the first time
    /// the underlying player gets a non-zero presentation size). Used to
    /// decide whether fullscreen should lock the device to portrait or
    /// landscape: a video taller than wide on a phone shouldn't force a
    /// 90° rotation that produces black side-bars.
    @State private var videoNaturalSize: CGSize?
    /// Mirrors the KMP-shared `forcePortraitFullscreenForVerticalVideos`
    /// preference (default ON). When ON, fullscreen on a portrait-aspect
    /// video keeps the device in portrait instead of forcing landscape.
    @AppStorage("force_portrait_fullscreen_for_vertical_videos")
    private var forcePortraitForVerticalVideos: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    init(videoCode: String, videoFeature: VideoFeature, commentFeature: CommentFeature) {
        self.videoCode = videoCode
        self.videoFeature = videoFeature
        self.commentFeature = commentFeature
        _viewModel = StateObject(wrappedValue: VideoDetailViewModel(videoFeature: videoFeature))
        _commentViewModel = StateObject(
            wrappedValue: CommentViewModel(feature: commentFeature, videoCode: videoCode)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                content
                    .ignoresSafeArea(.container, edges: ignoredContainerSafeAreaEdges)

                rootCommentComposer(layoutSize: proxy.size)
            }
            .animation(.easeInOut(duration: 0.2), value: shouldShowRootCommentComposer)
            .onPreferenceChange(CommentComposerHeightPreferenceKey.self) { height in
                guard height > 0, abs(commentComposerHeight - height) > 0.5 else { return }
                commentComposerHeight = height
            }
        }
            .logScreen("VideoDetail v=\(videoCode)")
            // Navigation bar (and its system back button) is hidden the
            // whole time. The player draws its own floating back button
            // inside the controls overlay — that way show/hide of the
            // back button is purely an overlay-layer change and doesn't
            // resize / shift the rest of the view tree.
            .toolbar(.hidden, for: .navigationBar)
            // SwiftUI's `.toolbar(.hidden, for: .navigationBar)` also turns
            // off the edge-swipe-to-go-back gesture on the underlying
            // UINavigationController. Re-enable it explicitly so the user
            // still has the standard iOS gesture to navigate back even
            // though we hide the nav bar.
            .enableInteractivePopOnHiddenNavBar(disabled: isPlayerFullscreen)
            // The video detail page always hides the tab bar — it's a
            // pushed sub-page that benefits from extra vertical space, not a
            // top-level tab. (Fullscreen state doesn't matter; both inline
            // and fullscreen want the tab bar gone.)
            // hidesTabBarOnAppear() drives the shared TabBarVisibilityController:
            // .onAppear sets hidden; .onDisappear withAnimation sets visible
            // again, producing the slide-in/out animation.
            .hidesTabBarOnAppear()
            .statusBarHidden(isPlayerFullscreen)
            .task {
                viewModel.loadIfNeeded(videoCode: videoCode)
            }
            .onDisappear {
                fullscreenOrientationTask?.cancel()
                fullscreenOrientationTask = nil
                // KSPlayer pauses itself in its own .onDisappear; the
                // detail VM no longer owns a player.
                if isPlayerFullscreen || isFullscreenOrientationLocked {
                    AppOrientationController.shared.unlockAfterFullscreen()
                    isFullscreenOrientationLocked = false
                }
            }
            // Apple-Music-style centred HUD for action results
            // (favorited / watch-later / playlist / subscribe / errors).
            // .overlay so it floats on top of everything, including the
            // player. allowsHitTesting(false) so it never blocks taps.
            // The HUD self-dismisses 1.2s after appearing (see .task
            // modifier on the inner view that's keyed on the message id).
            .overlay(alignment: .center) {
                if let actionMessage = viewModel.actionMessage {
                    AppleStyleHUD(
                        systemImage: actionMessage.systemImage,
                        message: actionMessage.message
                    )
                    .transition(
                        .scale(scale: 0.85)
                        .combined(with: .opacity)
                    )
                    .allowsHitTesting(false)
                    .task(id: actionMessage.id) {
                        // Auto-dismiss timer. The .task is keyed on the
                        // message id so consecutive HUDs (e.g. user
                        // mashes the favorite button) reset the timer
                        // rather than dismissing early.
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        // Make sure we're still showing the same message;
                        // if the user fired another action mid-sleep, the
                        // task is cancelled and we don't clear theirs.
                        if viewModel.actionMessage?.id == actionMessage.id {
                            withAnimation(.easeOut(duration: 0.25)) {
                                viewModel.actionMessage = nil
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: viewModel.actionMessage?.id)
            .onValueChange(of: isPlayerFullscreen) { newValue in
                // The fullscreen toggle button wraps `isPlayerFullscreen.toggle()`
                // in `withAnimation(.easeInOut(duration: 0.25))` so the
                // player frame can animate from inline 16:9 to fill-screen.
                // If we synchronously trigger AppOrientationController here,
                // UIKit fires a size-class / size change in the middle of
                // SwiftUI's animation transaction, and SwiftUI cancels the
                // running frame animation in favour of laying out for the
                // new orientation — the user perceives this as the animation
                // "going missing". Defer the orientation change until just
                // after the SwiftUI animation has completed (~0.30s, slightly
                // longer than the 0.25s curve to be safe). The player has
                // already animated to its new size by then; the subsequent
                // orientation rotation is its own UIKit-driven animation
                // and doesn't fight with SwiftUI.
                scheduleFullscreenOrientationUpdate(isFullscreen: newValue)
            }
    }

    /// Decides whether the player should rotate to landscape or stay in
    /// portrait when entering fullscreen. Defaults to landscape (existing
    /// behaviour); switches to portrait only when both:
    /// 1. The video's reported natural size is taller than wide.
    /// 2. The user has the "force portrait fullscreen for vertical
    ///    videos" preference enabled (default ON).
    private var fullscreenOrientation: VideoFullscreenOrientation {
        fullscreenOrientation(forNaturalSize: videoNaturalSize)
    }

    private func fullscreenOrientation(forNaturalSize naturalSize: CGSize?) -> VideoFullscreenOrientation {
        let isPortraitVideo: Bool = {
            guard let size = naturalSize else { return false }
            return size.height > size.width
        }()
        if isPortraitVideo && forcePortraitForVerticalVideos {
            return .portrait
        }
        return .landscape
    }

    private var ignoredContainerSafeAreaEdges: Edge.Set {
        isPlayerFullscreen ? .all : .bottom
    }

    private var shouldShowRootCommentComposer: Bool {
        guard !isPlayerFullscreen, pagerState.selectedTab == .comments else { return false }
        guard !isCommentInternalOverlayActive else { return false }
        guard isCommentComposerReady else { return false }
        if case .loaded = viewModel.state {
            return true
        }
        return false
    }

    private var isCommentComposerReady: Bool {
        if case .loaded = commentViewModel.state {
            return true
        }
        return false
    }

    @ViewBuilder
    private func rootCommentComposer(layoutSize: CGSize) -> some View {
        if shouldShowRootCommentComposer {
            CommentComposerBar(
                text: $commentComposeText,
                isSending: commentViewModel.runningActionIDs.contains("post-comment"),
                isReady: isCommentComposerReady,
                onSubmit: submitComment
            )
            .frame(width: leftPanelWidth(for: layoutSize))
            .reportCommentComposerHeight()
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("视频加载失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    viewModel.load(videoCode: videoCode)
                }
                .buttonStyle(.borderedProminent)
                CloudflareVerifyButton(errorMessage: message)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot):
            // Bilibili-style iPad layout: an outer HStack with two slots.
            // - Slot 0: a VStack (the "left panel") that hosts player + scroll.
            //   Player is ALWAYS the first child of this VStack at a stable tree
            //   position, so size-class flips never reparent it (which would
            //   rebuild @StateObject Coordinator + KSPlayerLayer → reload video).
            // - Slot 1: the related-videos sidebar, only mounted on iPad regular
            //   landscape. Mounting/unmounting it does NOT touch slot 0.
            //
            // Phone / iPad portrait collapses to a single full-width left panel
            // (no sidebar), giving the same visual as before for those modes.
            GeometryReader { proxy in
                let isWide = usesTabletRelatedSidebar(for: proxy.size)
                let leftWidth = leftPanelWidth(for: proxy.size)
                let inlineHeight = inlinePlayerHeight(panelWidth: leftWidth)
                let pagerMetrics = pagerState.layoutMetrics(
                    inlinePlayerHeight: inlineHeight,
                    containerHeight: proxy.size.height,
                    rawCollapseDistance: playerCollapseDistance(panelWidth: leftWidth)
                )

                HStack(alignment: .top, spacing: 0) {
                    ZStack(alignment: .top) {
                        let currentPlayerHeight = playerHeight(
                            panelWidth: leftWidth,
                            parentHeight: proxy.size.height
                        )
                        playerArea(snapshot: snapshot)
                            .frame(
                                width: leftWidth,
                                height: currentPlayerHeight
                            )

                        // Keep the tab pager mounted during fullscreen. Rebuilding
                        // the SwiftUI-hosted intro/comment pages while the player
                        // animates back to inline is a visible hitch on iPadOS 16.
                        // It keeps the inline layout metrics while hidden, so exit
                        // fullscreen does not have to re-expand the whole pager.
                        belowPlayerScroll(
                            snapshot: snapshot,
                            showsRelated: !isWide,
                            collapseDistance: pagerMetrics.collapseDistance,
                            playerScrollAway: pagerMetrics.playerScrollAway,
                            introductionContentClearance: introductionContentClearance(),
                            composerContentClearance: commentComposerContentClearance(
                                safeAreaBottom: proxy.safeAreaInsets.bottom
                            )
                        )
                        .frame(height: pagerMetrics.belowPlayerHeight)
                        .offset(y: pagerMetrics.belowPlayerTopOffset)
                        .opacity(isPlayerFullscreen ? 0 : 1)
                        .allowsHitTesting(!isPlayerFullscreen)

                        if !isPlayerFullscreen,
                           pagerMetrics.continuationProgress > 0 {
                            continuePlayingStrip(snapshot: snapshot, progress: pagerMetrics.continuationProgress)
                                .frame(width: leftWidth, height: playerContinuationStripHeight)
                        }
                    }
                    .frame(width: leftWidth, height: proxy.size.height, alignment: .top)
                    .clipped()

                    if isWide {
                        Divider()
                        TabletRelatedSidebar(
                            videos: snapshot.relatedVideos,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private func usesTabletRelatedSidebar(for size: CGSize) -> Bool {
        let isLandscape = currentInterfaceOrientation()?.isLandscape ?? (size.width > size.height)
        return horizontalSizeClass == .regular
            && size.width >= tabletLeftMinimumWidth + tabletSidebarMinimumWidth
            && isLandscape
            && !isPlayerFullscreen
    }

    private func leftPanelWidth(for size: CGSize) -> CGFloat {
        guard usesTabletRelatedSidebar(for: size) else { return size.width }
        return min(
            max(size.width * 0.64, tabletLeftMinimumWidth),
            size.width - tabletSidebarMinimumWidth
        )
    }

    /// Player 高度：
    /// - 全屏：撑满整个父容器
    /// - inline：固定为左 panel 宽度的 16:9，不随底部内容滚动缩小
    private func playerHeight(panelWidth: CGFloat, parentHeight: CGFloat) -> CGFloat {
        if isPlayerFullscreen { return parentHeight }
        return inlinePlayerHeight(panelWidth: panelWidth)
    }

    private func inlinePlayerHeight(panelWidth: CGFloat) -> CGFloat {
        panelWidth * 9 / 16
    }

    private func playerCollapseDistance(panelWidth: CGFloat) -> CGFloat {
        max(panelWidth * 9 / 16 - playerContinuationStripHeight, 1)
    }

    private func playerArea(snapshot: VideoDetailScreenSnapshot) -> some View {
        return KSPlayerView(
            snapshot: snapshot,
            isFullscreen: $isPlayerFullscreen,
            onProgress: { viewModel.recordPlaybackPosition(seconds: $0) },
            onPlaybackEnded: { viewModel.recordPlaybackPosition(seconds: 0) },
            onPlayingChanged: { newValue in
                guard pagerState.isPlayerPlaying != newValue else { return }
                withTransaction(Transaction(animation: nil)) {
                    pagerState.setPlayerPlaying(newValue)
                }
            },
            onBack: { dismiss() },
            playRequestToken: playerPlayRequestToken,
            onNaturalSize: { size in
                let orientation = fullscreenOrientation(forNaturalSize: size)
                videoNaturalSize = size
                if isPlayerFullscreen {
                    AppOrientationController.shared.lockForFullscreen(to: orientation)
                    isFullscreenOrientationLocked = true
                }
            }
        )
    }

    private func continuePlayingStrip(snapshot: VideoDetailScreenSnapshot, progress: CGFloat) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                pagerState.expandPlayer()
            }
            playerPlayRequestToken &+= 1
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                Text("继续播放")
                    .font(.subheadline.weight(.semibold))
                Text(snapshot.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(progress)
        .offset(y: -8 * (1 - progress))
    }

    private func belowPlayerScroll(
        snapshot: VideoDetailScreenSnapshot,
        showsRelated: Bool,
        collapseDistance: CGFloat,
        playerScrollAway: CGFloat,
        introductionContentClearance: CGFloat,
        composerContentClearance: CGFloat
    ) -> some View {
        let contentRevision = tabContentRevision(snapshot: snapshot, showsRelated: showsRelated)

        return VideoDetailPagerContainer(
            state: $pagerState,
            collapseDistance: collapseDistance,
            playerScrollAway: playerScrollAway,
            introductionContentBottomPadding: introductionContentClearance,
            commentsContentBottomPadding: composerContentClearance,
            introductionContentRevision: contentRevision.introduction,
            commentsContentRevision: contentRevision.comments,
            introduction: {
                AndroidStyleIntroduction(
                    snapshot: snapshot,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature,
                    isArtistActionRunning: viewModel.isActionRunning("artistSubscription"),
                    onToggleArtistSubscription: { viewModel.toggleArtistSubscription(snapshot: snapshot) },
                    onToggleFavorite: { viewModel.toggleFavorite(snapshot: snapshot) },
                    onToggleWatchLater: { viewModel.toggleWatchLater(snapshot: snapshot) },
                    onSetMyListItem: { item, isSelected in viewModel.setMyListItem(snapshot: snapshot, item: item, isSelected: isSelected) },
                    onShowMessage: { viewModel.showActionMessage($0) },
                    showsRelated: showsRelated
                )
                .padding(.top, 16)
            },
            comments: {
                CommentView(
                    viewModel: commentViewModel,
                    onOverlayActivityChanged: { isActive in
                        isCommentInternalOverlayActive = isActive
                    }
                )
                .padding(.top, 16)
            }
        )
    }

    private func submitComment() {
        guard isCommentComposerReady else { return }
        if commentViewModel.postComment(text: commentComposeText) {
            commentComposeText = ""
        }
    }

    private func scheduleFullscreenOrientationUpdate(isFullscreen: Bool) {
        fullscreenOrientationTask?.cancel()
        fullscreenOrientationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, isPlayerFullscreen == isFullscreen else { return }
            if isFullscreen {
                AppOrientationController.shared.lockForFullscreen(to: fullscreenOrientation)
                isFullscreenOrientationLocked = true
            } else if isFullscreenOrientationLocked {
                AppOrientationController.shared.unlockAfterFullscreen()
                isFullscreenOrientationLocked = false
            }
        }
    }

    private func commentComposerContentClearance(safeAreaBottom: CGFloat) -> CGFloat {
        let containerBottomInset = currentWindowBottomSafeAreaInset()
        let isKeyboardSafeAreaActive = safeAreaBottom > containerBottomInset + 1
        let composerHeight = max(commentComposerHeight, CommentComposerBar.compactHeight)
        return composerHeight
            + (isKeyboardSafeAreaActive ? 0 : containerBottomInset)
            + commentComposerBottomSlack
    }

    private func introductionContentClearance() -> CGFloat {
        currentWindowBottomSafeAreaInset() + 24
    }

    private func currentWindowBottomSafeAreaInset() -> CGFloat {
        currentWindowScene()?
            .windows
            .first { $0.isKeyWindow }?
            .safeAreaInsets
            .bottom ?? 0
    }

    private func currentInterfaceOrientation() -> UIInterfaceOrientation? {
        currentWindowScene()?.interfaceOrientation
    }

    private func currentWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private func tabContentRevision(
        snapshot: VideoDetailScreenSnapshot,
        showsRelated: Bool
    ) -> VideoDetailTabContentRevision {
        var introductionHasher = Hasher()
        introductionHasher.combine(showsRelated)
        introductionHasher.combine(viewModel.isActionRunning("artistSubscription"))
        snapshot.hash(into: &introductionHasher)

        var commentsHasher = Hasher()
        commentsHasher.combine(ObjectIdentifier(commentViewModel))

        return VideoDetailTabContentRevision(
            introduction: introductionHasher.finalize(),
            comments: commentsHasher.finalize()
        )
    }
}

private struct CommentComposerBar: View {
    static let compactHeight: CGFloat = 49

    @Binding var text: String
    let isSending: Bool
    let isReady: Bool
    let onSubmit: () -> Void
    @FocusState private var isFieldFocused: Bool

    private var canSubmit: Bool {
        isReady && text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !isSending
    }

    var body: some View {
        composerControls
            .padding(.horizontal, 16)
            .frame(minHeight: Self.compactHeight)
            .frame(maxWidth: .infinity)
            .commentComposerBarChrome()
            .onValueChange(of: isFieldFocused) { isFocused in
                guard isFocused else { return }
                CommentKeyboardTransparency.applySoon()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                CommentKeyboardTransparency.applySoon()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                CommentKeyboardTransparency.applySoon()
            }
            .onDisappear {
                isFieldFocused = false
            }
    }

    @ViewBuilder
    private var composerControls: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                composerControlRow
            }
        } else {
            composerControlRow
        }
    }

    private var composerControlRow: some View {
        HStack(spacing: 10) {
            TextField("输入评论", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .lineLimit(1...4)
                .focused($isFieldFocused)
                .onSubmit {
                    guard canSubmit else { return }
                    onSubmit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .commentComposerFieldChrome()
                .layoutPriority(1)

            Button(action: onSubmit) {
                Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                    .font(.headline)
                    .frame(width: 42, height: 42)
            }
            .disabled(!canSubmit)
            .foregroundStyle(canSubmit ? Color.accentColor : Color.secondary)
            .accessibilityLabel("发送评论")
            .commentComposerSendButtonChrome(isEnabled: canSubmit)
        }
    }
}

private struct CommentComposerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func reportCommentComposerHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CommentComposerHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
    }

    @ViewBuilder
    func commentComposerFieldChrome() -> some View {
        background(Color(.secondarySystemBackground), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.16), lineWidth: 0.5)
            }
            .contentShape(Capsule())
    }

    func commentComposerSendButtonChrome(isEnabled _: Bool) -> some View {
        buttonStyle(.plain)
            .background(Color(.secondarySystemBackground), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 0.5)
            }
            .contentShape(Circle())
    }

    func commentComposerBarChrome() -> some View {
        background(Color(.systemGroupedBackground).opacity(0.96))
            .overlay(alignment: .top) {
                Divider()
                    .opacity(0.35)
            }
    }
}

private enum CommentKeyboardTransparency {
    @MainActor
    static func applySoon() {
        guard #available(iOS 26.0, *) else { return }
        apply()
        for delay in [40_000_000, 120_000_000, 260_000_000] {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay))
                apply()
            }
        }
    }

    @MainActor
    private static func apply() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .filter { isKeyboardWindow($0) }
            .forEach { window in
                clearKeyboardChrome(in: window, depth: 0)
            }
    }

    private static func isKeyboardWindow(_ window: UIWindow) -> Bool {
        let className = NSStringFromClass(type(of: window))
        return className.contains("UIRemoteKeyboardWindow")
            || className.contains("UITextEffectsWindow")
    }

    private static func clearKeyboardChrome(in view: UIView, depth: Int) {
        let className = NSStringFromClass(type(of: view))
        if depth <= 2
            || className.contains("InputSet")
            || className.contains("Keyboard")
            || className.contains("TextEffects")
            || className.contains("VisualEffect")
            || className.contains("Backdrop")
            || className.contains("Material") {
            view.backgroundColor = .clear
            view.isOpaque = false
        }
        if let visualEffectView = view as? UIVisualEffectView {
            visualEffectView.effect = nil
            visualEffectView.contentView.backgroundColor = .clear
        }
        view.subviews.forEach { clearKeyboardChrome(in: $0, depth: depth + 1) }
    }
}

private enum VideoPlayerCollapseModel {
    static func nextCollapseOffset(
        currentCollapseOffset: CGFloat,
        activeTabOffset: CGFloat,
        previousActiveTabOffset: CGFloat?,
        collapseDistance: CGFloat
    ) -> CGFloat {
        let clampedCurrent = clamp(currentCollapseOffset, upperBound: collapseDistance)

        guard let previousActiveTabOffset else {
            let nonnegativeActiveOffset = max(0, activeTabOffset)
            return min(collapseDistance, max(clampedCurrent, nonnegativeActiveOffset))
        }

        let delta = activeTabOffset - previousActiveTabOffset
        if abs(delta) > 0.5 {
            return clamp(clampedCurrent + delta, upperBound: collapseDistance)
        }

        return clampedCurrent
    }

    private static func clamp(_ value: CGFloat, upperBound: CGFloat) -> CGFloat {
        min(max(value, 0), max(upperBound, 0))
    }
}

private struct VideoDetailPagerLayoutMetrics {
    let collapseDistance: CGFloat
    let playerScrollAway: CGFloat
    let belowPlayerTopOffset: CGFloat
    let belowPlayerHeight: CGFloat
    let continuationProgress: CGFloat
}

private struct VideoDetailPagerState: Equatable {
    var selectedTab: VideoPageTab = .introduction
    var collapseOffset: CGFloat = 0
    var tabOffsets: [VideoPageTab: CGFloat] = [:]
    var isPlayerPlaying: Bool = false

    func layoutMetrics(
        inlinePlayerHeight: CGFloat,
        containerHeight: CGFloat,
        rawCollapseDistance: CGFloat
    ) -> VideoDetailPagerLayoutMetrics {
        let collapseDistance = isPlayerPlaying ? 0 : max(rawCollapseDistance, 0)
        let playerScrollAway = isPlayerPlaying ? 0 : Self.clamp(collapseOffset, upperBound: collapseDistance)
        let belowPlayerTopOffset = max(inlinePlayerHeight - playerScrollAway, 0)
        let fadeDistance: CGFloat = 72
        let continuationProgress: CGFloat
        if rawCollapseDistance > 1 {
            continuationProgress = min(
                max((playerScrollAway - (rawCollapseDistance - fadeDistance)) / fadeDistance, 0),
                1
            )
        } else {
            continuationProgress = 0
        }

        return VideoDetailPagerLayoutMetrics(
            collapseDistance: collapseDistance,
            playerScrollAway: playerScrollAway,
            belowPlayerTopOffset: belowPlayerTopOffset,
            belowPlayerHeight: max(0, containerHeight - belowPlayerTopOffset),
            continuationProgress: continuationProgress
        )
    }

    func contentTopInset(for _: VideoPageTab, playerScrollAway: CGFloat) -> CGFloat {
        max(playerScrollAway, 0)
    }

    func storedOffset(for tab: VideoPageTab) -> CGFloat? {
        tabOffsets[tab]
    }

    mutating func setPlayerPlaying(_ isPlaying: Bool) {
        isPlayerPlaying = isPlaying
        if isPlaying {
            collapseOffset = 0
        }
    }

    mutating func expandPlayer() {
        collapseOffset = 0
    }

    mutating func selectTab(_ tab: VideoPageTab, collapseDistance: CGFloat) {
        selectedTab = tab
        clampCollapse(to: collapseDistance)
    }

    mutating func updateTabOffset(_ tab: VideoPageTab, offset: CGFloat, collapseDistance: CGFloat) {
        guard tab == selectedTab else { return }
        guard !isPlayerPlaying else {
            collapseOffset = 0
            return
        }
        let trackedOffset = Self.clamp(offset, upperBound: collapseDistance)
        let previousActiveOffset = tabOffsets[tab]
        let previousCollapseOffset = collapseOffset
        let nextCollapseOffset = nextCollapseOffset(
            activeTabOffset: trackedOffset,
            previousActiveTabOffset: previousActiveOffset,
            collapseDistance: collapseDistance
        )
        guard previousActiveOffset != trackedOffset
            || abs(previousCollapseOffset - nextCollapseOffset) > 0.5 else {
            return
        }
        tabOffsets[tab] = trackedOffset
        collapseOffset = nextCollapseOffset
    }

    private func nextCollapseOffset(
        activeTabOffset: CGFloat,
        previousActiveTabOffset: CGFloat?,
        collapseDistance: CGFloat
    ) -> CGFloat {
        VideoPlayerCollapseModel.nextCollapseOffset(
            currentCollapseOffset: collapseOffset,
            activeTabOffset: activeTabOffset,
            previousActiveTabOffset: previousActiveTabOffset,
            collapseDistance: collapseDistance
        )
    }

    mutating func beginInteracting(with tab: VideoPageTab, collapseDistance: CGFloat) {
        guard selectedTab != tab else { return }
        selectTab(tab, collapseDistance: collapseDistance)
    }

    mutating func handleTopPull(tab: VideoPageTab, delta: CGFloat, collapseDistance: CGFloat) {
        guard tab == selectedTab, !isPlayerPlaying, delta > 0, collapseOffset > 0 else { return }
        collapseOffset = Self.clamp(collapseOffset - delta, upperBound: collapseDistance)
    }

    mutating func clampCollapse(to collapseDistance: CGFloat) {
        collapseOffset = Self.clamp(collapseOffset, upperBound: collapseDistance)
    }

    private static func clamp(_ value: CGFloat, upperBound: CGFloat) -> CGFloat {
        min(max(value, 0), max(upperBound, 0))
    }
}

private enum VideoPageTab: String, CaseIterable, Identifiable {
    case introduction
    case comments

    var id: String { rawValue }

    var pageIndex: Int {
        switch self {
        case .introduction: return 0
        case .comments: return 1
        }
    }

    static func page(at index: Int) -> VideoPageTab {
        index <= 0 ? .introduction : .comments
    }

    var scrollCoordinateSpaceName: String {
        "bottomScroll-\(rawValue)"
    }

    var title: String {
        switch self {
        case .introduction:
            return String(localized: "简介")
        case .comments:
            return String(localized: "评论")
        }
    }
}

private struct VideoDetailTabContentRevision: Equatable {
    let introduction: Int
    let comments: Int
}

private struct VideoDetailTabPage {
    let tab: VideoPageTab
    let contentBottomPadding: CGFloat
    let contentTopInset: CGFloat
    let storedContentOffset: CGFloat?
    let isSelected: Bool
    let collapseDistance: CGFloat
    let contentUpdateRevision: Int
    let onOffsetChange: (VideoPageTab, CGFloat) -> Void
    let onInteractionBegan: (VideoPageTab) -> Void
    let onTopPullDelta: (VideoPageTab, CGFloat) -> Void
    let content: () -> AnyView

    init<Content: View>(
        tab: VideoPageTab,
        contentBottomPadding: CGFloat,
        contentTopInset: CGFloat,
        storedContentOffset: CGFloat?,
        isSelected: Bool,
        collapseDistance: CGFloat,
        contentUpdateRevision: Int,
        onOffsetChange: @escaping (VideoPageTab, CGFloat) -> Void,
        onInteractionBegan: @escaping (VideoPageTab) -> Void,
        onTopPullDelta: @escaping (VideoPageTab, CGFloat) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tab = tab
        self.contentBottomPadding = contentBottomPadding
        self.contentTopInset = contentTopInset
        self.storedContentOffset = storedContentOffset
        self.isSelected = isSelected
        self.collapseDistance = collapseDistance
        self.contentUpdateRevision = contentUpdateRevision
        self.onOffsetChange = onOffsetChange
        self.onInteractionBegan = onInteractionBegan
        self.onTopPullDelta = onTopPullDelta
        self.content = { AnyView(content()) }
    }
}

private struct VideoDetailPagerContainer<Introduction: View, Comments: View>: View {
    @Binding var state: VideoDetailPagerState
    let collapseDistance: CGFloat
    let playerScrollAway: CGFloat
    let introductionContentBottomPadding: CGFloat
    let commentsContentBottomPadding: CGFloat
    let introductionContentRevision: Int
    let commentsContentRevision: Int
    let introduction: () -> Introduction
    let comments: () -> Comments

    private var selectedTabBinding: Binding<VideoPageTab> {
        Binding(
            get: { state.selectedTab },
            set: { newTab in
                mutateState { $0.selectTab(newTab, collapseDistance: collapseDistance) }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Content", selection: selectedTabBinding) {
                ForEach(VideoPageTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.background)

            VideoDetailTabPager(
                selectedTab: selectedTabBinding,
                introduction: tabPage(
                    .introduction,
                    contentBottomPadding: introductionContentBottomPadding,
                    contentUpdateRevision: introductionContentRevision,
                    content: introduction
                ),
                comments: tabPage(
                    .comments,
                    contentBottomPadding: commentsContentBottomPadding,
                    contentUpdateRevision: commentsContentRevision,
                    content: comments
                )
            )
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onValueChange(of: collapseDistance) { newValue in
            mutateState { $0.clampCollapse(to: newValue) }
        }
    }

    private func tabPage<Content: View>(
        _ tab: VideoPageTab,
        contentBottomPadding: CGFloat,
        contentUpdateRevision: Int,
        @ViewBuilder content: @escaping () -> Content
    ) -> VideoDetailTabPage {
        VideoDetailTabPage(
            tab: tab,
            contentBottomPadding: contentBottomPadding,
            contentTopInset: state.contentTopInset(for: tab, playerScrollAway: playerScrollAway),
            storedContentOffset: state.storedOffset(for: tab),
            isSelected: state.selectedTab == tab,
            collapseDistance: collapseDistance,
            contentUpdateRevision: contentUpdateRevision,
            onOffsetChange: { tab, offset in
                mutateState {
                    $0.updateTabOffset(tab, offset: offset, collapseDistance: collapseDistance)
                }
            },
            onInteractionBegan: { tab in
                mutateState {
                    $0.beginInteracting(with: tab, collapseDistance: collapseDistance)
                }
            },
            onTopPullDelta: { tab, delta in
                mutateState {
                    $0.handleTopPull(tab: tab, delta: delta, collapseDistance: collapseDistance)
                }
            },
            content: content
        )
    }

    private func mutateState(_ mutation: (inout VideoDetailPagerState) -> Void) {
        withTransaction(Transaction(animation: nil)) {
            var nextState = state
            mutation(&nextState)
            if nextState != state {
                state = nextState
            }
        }
    }
}

private final class VideoDetailVerticalScrollPageCoordinator: NSObject, UIScrollViewDelegate {
    var tab: VideoPageTab
    var onOffsetChange: (VideoPageTab, CGFloat) -> Void
    var onInteractionBegan: (VideoPageTab) -> Void
    var onTopPullDelta: (VideoPageTab, CGFloat) -> Void
    var onVerticalInteractionBegan: () -> Void = {}
    var visualTopContentOffsetY: CGFloat = 0
    private var lastReportedOffset: CGFloat?
    private var lastTopPullTranslationY: CGFloat = 0

    init(
        tab: VideoPageTab,
        onOffsetChange: @escaping (VideoPageTab, CGFloat) -> Void,
        onInteractionBegan: @escaping (VideoPageTab) -> Void,
        onTopPullDelta: @escaping (VideoPageTab, CGFloat) -> Void
    ) {
        self.tab = tab
        self.onOffsetChange = onOffsetChange
        self.onInteractionBegan = onInteractionBegan
        self.onTopPullDelta = onTopPullDelta
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.verticalContentOffsetExcludingBounce
        guard lastReportedOffset.map({ abs($0 - offset) > 0.5 }) ?? true else { return }
        lastReportedOffset = offset
        onOffsetChange(tab, offset)
    }

    @objc func handlePan(_ panGestureRecognizer: UIPanGestureRecognizer) {
        guard let scrollView = panGestureRecognizer.view as? UIScrollView else { return }
        switch panGestureRecognizer.state {
        case .began:
            onVerticalInteractionBegan()
            onInteractionBegan(tab)
            lastTopPullTranslationY = 0
        case .changed:
            guard scrollView.verticalContentOffsetExcludingBounce <= visualTopContentOffsetY + 0.5 else {
                lastTopPullTranslationY = panGestureRecognizer.translation(in: scrollView).y
                return
            }
            let translationY = panGestureRecognizer.translation(in: scrollView).y
            let delta = translationY - lastTopPullTranslationY
            lastTopPullTranslationY = translationY
            if delta > 0 {
                onTopPullDelta(tab, delta)
            }
        default:
            lastTopPullTranslationY = 0
        }
    }
}

private final class VideoDetailVerticalScrollPageViewController: UIViewController {
    private let coordinator: VideoDetailVerticalScrollPageCoordinator
    private let scrollView = VerticalScrollView()
    private let contentView = UIView()
    private let collapseSpacerView = UIView()
    private let host = UIHostingController(rootView: AnyView(EmptyView()))
    private var hostTopConstraint: NSLayoutConstraint!
    private var hostMinimumHeightConstraint: NSLayoutConstraint!
    private var contentMinimumHeightConstraint: NSLayoutConstraint!
    private var collapseSpacerHeightConstraint: NSLayoutConstraint!
    private var contentUpdateRevision: Int?
    private var wasSelected = false
    private var topAlignmentGeneration = 0
    private var pendingTopAlignmentRetryCount = 0
    private var pendingTopAlignmentTargetOffsetY: CGFloat?

    init(tab: VideoPageTab) {
        coordinator = VideoDetailVerticalScrollPageCoordinator(
            tab: tab,
            onOffsetChange: { _, _ in },
            onInteractionBegan: { _ in },
            onTopPullDelta: { _, _ in }
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.keyboardDismissMode = .interactive
        scrollView.delegate = coordinator
        scrollView.panGestureRecognizer.addTarget(coordinator, action: #selector(VideoDetailVerticalScrollPageCoordinator.handlePan(_:)))
        scrollView.shouldBeginVerticalPan = { [weak self] panGestureRecognizer, view in
            self?.resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
            let velocity = panGestureRecognizer.velocity(in: view)
            return abs(velocity.x) <= abs(velocity.y) * 1.05
        }
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        contentView.addSubview(host.view)
        host.didMove(toParent: self)

        collapseSpacerView.translatesAutoresizingMaskIntoConstraints = false
        collapseSpacerView.backgroundColor = .clear
        contentView.addSubview(collapseSpacerView)

        hostTopConstraint = host.view.topAnchor.constraint(equalTo: contentView.topAnchor)
        hostMinimumHeightConstraint = host.view.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        contentMinimumHeightConstraint = contentView.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor,
            constant: 1
        )
        collapseSpacerHeightConstraint = collapseSpacerView.heightAnchor.constraint(equalToConstant: 1)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentMinimumHeightConstraint,

            host.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostTopConstraint,
            hostMinimumHeightConstraint,

            collapseSpacerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collapseSpacerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collapseSpacerView.topAnchor.constraint(equalTo: host.view.bottomAnchor),
            collapseSpacerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collapseSpacerHeightConstraint
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resolvePendingTopAlignmentIfPossible()
    }

    func update(page: VideoDetailTabPage) {
        loadViewIfNeeded()
        coordinator.tab = page.tab
        coordinator.onOffsetChange = page.onOffsetChange
        coordinator.onInteractionBegan = page.onInteractionBegan
        coordinator.onTopPullDelta = page.onTopPullDelta
        coordinator.onVerticalInteractionBegan = { [weak self] in
            self?.resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
        }
        let wasPageSelected = wasSelected
        wasSelected = page.isSelected
        if !page.isSelected {
            cancelPendingTopAlignment()
        }
        if contentUpdateRevision != page.contentUpdateRevision {
            contentUpdateRevision = page.contentUpdateRevision
            host.rootView = page.content()
        }

        let previousVisualTopContentOffsetY = coordinator.visualTopContentOffsetY
        let contentTopInset = resolvedContentTopInset(for: page)
        coordinator.visualTopContentOffsetY = contentTopInset
        let storedContentOffset = page.storedContentOffset ?? 0
        let shouldAlignTopOnActivation = page.isSelected
            && !wasPageSelected
            && storedContentOffset <= contentTopInset + 0.5
        hostTopConstraint.constant = contentTopInset
        applyBottomContentInset(page.contentBottomPadding)
        let collapseSpacerHeight = max(page.collapseDistance - contentTopInset + 1, 1)
        collapseSpacerHeightConstraint.constant = collapseSpacerHeight
        contentMinimumHeightConstraint.constant = contentTopInset
            + collapseSpacerHeight
        if shouldAlignTopOnActivation {
            requestTopAlignment(targetOffsetY: contentTopInset)
        } else if pendingTopAlignmentTargetOffsetY != nil {
            pendingTopAlignmentTargetOffsetY = contentTopInset
            resolvePendingTopAlignmentSoon()
        } else {
            preserveVisualTopIfNeeded(
                previousOffsetY: previousVisualTopContentOffsetY,
                targetOffsetY: contentTopInset
            )
        }
    }

    private func resolvedContentTopInset(for page: VideoDetailTabPage) -> CGFloat {
        min(max(page.contentTopInset, 0), max(page.collapseDistance, 0))
    }

    private func applyBottomContentInset(_ bottomInset: CGFloat) {
        let resolvedBottomInset = max(bottomInset, 0)
        guard abs(scrollView.contentInset.bottom - resolvedBottomInset) > 0.5 else { return }
        scrollView.contentInset.bottom = resolvedBottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = resolvedBottomInset
    }

    private func requestTopAlignment(targetOffsetY: CGFloat) {
        topAlignmentGeneration &+= 1
        pendingTopAlignmentRetryCount = 0
        pendingTopAlignmentTargetOffsetY = targetOffsetY
        resolvePendingTopAlignmentSoon()
    }

    private func resolvePendingTopAlignmentSoon() {
        let generation = topAlignmentGeneration
        resolvePendingTopAlignmentIfPossible()
        schedulePendingTopAlignmentRetry(generation: generation)
    }

    private func schedulePendingTopAlignmentRetry(generation: Int) {
        guard pendingTopAlignmentTargetOffsetY != nil,
              pendingTopAlignmentRetryCount < 8 else {
            return
        }
        pendingTopAlignmentRetryCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(16)) { [weak self] in
            guard let self, self.topAlignmentGeneration == generation else { return }
            self.resolvePendingTopAlignmentIfPossible()
            self.schedulePendingTopAlignmentRetry(generation: generation)
        }
    }

    private func resolvePendingTopAlignmentIfPossible(allowDuringInteraction: Bool = false) {
        guard let targetOffsetY = pendingTopAlignmentTargetOffsetY else { return }
        if !allowDuringInteraction {
            guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating else { return }
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        scrollView.layoutIfNeeded()
        contentView.layoutIfNeeded()
        let topOffsetY = clampedContentOffsetY(targetOffsetY)
        guard abs(topOffsetY - targetOffsetY) <= 0.5 else { return }
        if abs(scrollView.contentOffset.y - topOffsetY) > 0.5 {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: topOffsetY), animated: false)
        }
        if abs(scrollView.verticalContentOffsetExcludingBounce - targetOffsetY) <= 0.5 {
            cancelPendingTopAlignment()
        }
    }

    private func cancelPendingTopAlignment() {
        pendingTopAlignmentRetryCount = 0
        pendingTopAlignmentTargetOffsetY = nil
    }

    func settleAfterHorizontalActivation() {
        loadViewIfNeeded()
        let targetOffsetY = coordinator.visualTopContentOffsetY
        guard scrollView.verticalContentOffsetExcludingBounce <= targetOffsetY + 0.5 else { return }
        requestTopAlignment(targetOffsetY: targetOffsetY)
        resolvePendingTopAlignmentIfPossible(allowDuringInteraction: true)
    }

    private func preserveVisualTopIfNeeded(previousOffsetY: CGFloat, targetOffsetY: CGFloat) {
        guard abs(previousOffsetY - targetOffsetY) > 0.5 else { return }
        guard abs(scrollView.verticalContentOffsetExcludingBounce - previousOffsetY) <= 1 else { return }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let topOffsetY = clampedContentOffsetY(targetOffsetY)
        guard abs(scrollView.contentOffset.y - topOffsetY) > 0.5 else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: topOffsetY), animated: false)
    }

    private func clampedContentOffsetY(_ offsetY: CGFloat) -> CGFloat {
        let inset = scrollView.adjustedContentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
        return min(max(offsetY, minOffsetY), maxOffsetY)
    }
}

private final class VerticalScrollView: UIScrollView {
    var shouldBeginVerticalPan: ((UIPanGestureRecognizer, UIView) -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
           panGestureRecognizer === self.panGestureRecognizer {
            return shouldBeginVerticalPan?(panGestureRecognizer, self) ?? true
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

private extension UIScrollView {
    var verticalContentOffsetExcludingBounce: CGFloat {
        let inset = adjustedContentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, contentSize.height - bounds.height + inset.bottom)
        return min(max(contentOffset.y, minOffsetY), maxOffsetY) + inset.top
    }
}

private struct VideoDetailTabPager: UIViewControllerRepresentable {
    @Binding var selectedTab: VideoPageTab
    let introduction: VideoDetailTabPage
    let comments: VideoDetailTabPage

    init(
        selectedTab: Binding<VideoPageTab>,
        introduction: VideoDetailTabPage,
        comments: VideoDetailTabPage
    ) {
        _selectedTab = selectedTab
        self.introduction = introduction
        self.comments = comments
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedTab: $selectedTab)
    }

    func makeUIViewController(context: Context) -> PagingViewController {
        PagingViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: PagingViewController, context: Context) {
        context.coordinator.selectedTab = $selectedTab
        uiViewController.updatePages(
            introduction: introduction,
            comments: comments,
            selectedIndex: selectedTab.pageIndex,
            animated: context.coordinator.shouldAnimateProgrammaticSelection(to: selectedTab.pageIndex)
        )
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var selectedTab: Binding<VideoPageTab>
        var onSelectedIndexSettled: ((Int) -> Void)?
        private var lastProgrammaticIndex: Int?

        init(selectedTab: Binding<VideoPageTab>) {
            self.selectedTab = selectedTab
        }

        func shouldAnimateProgrammaticSelection(to index: Int) -> Bool {
            defer { lastProgrammaticIndex = index }
            guard let lastProgrammaticIndex else { return false }
            return lastProgrammaticIndex != index
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateSelectedTab(from: scrollView)
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            updateSelectedTab(from: scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                updateSelectedTab(from: scrollView)
            }
        }

        func shouldBeginHorizontalPagingPan(
            panGestureRecognizer: UIPanGestureRecognizer,
            in view: UIView
        ) -> Bool {
            let startLocation = panGestureRecognizer.location(in: view)
            guard startLocation.x > 24 else { return false }
            guard !view.hasScrollableHorizontalDescendant(at: startLocation, excluding: view) else {
                return false
            }

            let translation = panGestureRecognizer.translation(in: view)
            let velocity = panGestureRecognizer.velocity(in: view)
            let horizontal = max(abs(translation.x), abs(velocity.x) * 0.05)
            let vertical = max(abs(translation.y), abs(velocity.y) * 0.05)
            return horizontal > 8 && horizontal > vertical * 1.18
        }

        private func updateSelectedTab(from scrollView: UIScrollView) {
            let width = scrollView.bounds.width
            guard width > 0 else { return }
            let index = Int(round(scrollView.contentOffset.x / width))
            let tab = VideoPageTab.page(at: index)
            if selectedTab.wrappedValue != tab {
                selectedTab.wrappedValue = tab
            }
            DispatchQueue.main.async { [weak self] in
                self?.onSelectedIndexSettled?(index)
            }
        }
    }

    final class PagingViewController: UIViewController {
        private let coordinator: Coordinator
        private let scrollView = PagingScrollView()
        private let contentView = UIView()
        private let introductionPage = VideoDetailVerticalScrollPageViewController(tab: .introduction)
        private let commentsPage = VideoDetailVerticalScrollPageViewController(tab: .comments)
        private var selectedIndex = 0
        private var lastSettledSelectedIndex: Int?
        private var pendingSelectedIndex: Int?
        private var lastLaidOutWidth: CGFloat = 0

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear

            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.backgroundColor = .clear
            scrollView.isPagingEnabled = true
            scrollView.bounces = false
            scrollView.alwaysBounceHorizontal = false
            scrollView.alwaysBounceVertical = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.isDirectionalLockEnabled = true
            scrollView.contentInsetAdjustmentBehavior = .never
            scrollView.delegate = coordinator
            coordinator.onSelectedIndexSettled = { [weak self] index in
                self?.settlePageAfterHorizontalSelection(index)
            }
            scrollView.shouldBeginPagingPan = { [weak self] panGestureRecognizer, view in
                self?.coordinator.shouldBeginHorizontalPagingPan(
                    panGestureRecognizer: panGestureRecognizer,
                    in: view
                ) ?? true
            }
            view.addSubview(scrollView)

            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.backgroundColor = .clear
            scrollView.addSubview(contentView)

            addPage(introductionPage)
            addPage(commentsPage)

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

                introductionPage.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                introductionPage.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                introductionPage.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                introductionPage.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                introductionPage.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

                commentsPage.view.leadingAnchor.constraint(equalTo: introductionPage.view.trailingAnchor),
                commentsPage.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                commentsPage.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                commentsPage.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                commentsPage.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                commentsPage.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let width = scrollView.bounds.width
            let widthChanged = abs(width - lastLaidOutWidth) > 0.5
            lastLaidOutWidth = width
            if let pendingSelectedIndex {
                self.pendingSelectedIndex = nil
                setSelectedIndex(pendingSelectedIndex, animated: false)
            } else if widthChanged {
                setSelectedIndex(selectedIndex, animated: false)
            }
        }

        func updatePages(
            introduction: VideoDetailTabPage,
            comments: VideoDetailTabPage,
            selectedIndex: Int,
            animated: Bool
        ) {
            loadViewIfNeeded()
            self.selectedIndex = min(max(selectedIndex, 0), VideoPageTab.allCases.count - 1)
            introductionPage.update(page: introduction)
            commentsPage.update(page: comments)
            settleSelectedPageIfNeeded(self.selectedIndex)
            guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating else { return }
            setSelectedIndex(self.selectedIndex, animated: animated)
        }

        private func addPage(_ page: UIViewController) {
            addChild(page)
            page.view.translatesAutoresizingMaskIntoConstraints = false
            page.view.backgroundColor = .clear
            contentView.addSubview(page.view)
            page.didMove(toParent: self)
        }

        private func setSelectedIndex(_ index: Int, animated: Bool) {
            selectedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            let width = scrollView.bounds.width
            guard width > 0 else {
                pendingSelectedIndex = selectedIndex
                return
            }
            let targetOffset = CGPoint(x: CGFloat(selectedIndex) * width, y: 0)
            guard abs(scrollView.contentOffset.x - targetOffset.x) > 0.5 else { return }
            scrollView.setContentOffset(targetOffset, animated: animated)
        }

        private func settleSelectedPageIfNeeded(_ index: Int) {
            let clampedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            guard lastSettledSelectedIndex != clampedIndex else { return }
            lastSettledSelectedIndex = clampedIndex
            settlePageAfterHorizontalSelection(clampedIndex)
        }

        private func settlePageAfterHorizontalSelection(_ index: Int) {
            lastSettledSelectedIndex = min(max(index, 0), VideoPageTab.allCases.count - 1)
            switch VideoPageTab.page(at: index) {
            case .introduction:
                introductionPage.settleAfterHorizontalActivation()
            case .comments:
                commentsPage.settleAfterHorizontalActivation()
            }
        }
    }

    final class PagingScrollView: UIScrollView {
        var shouldBeginPagingPan: ((UIPanGestureRecognizer, UIView) -> Bool)?

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
               panGestureRecognizer === self.panGestureRecognizer {
                return shouldBeginPagingPan?(panGestureRecognizer, self) ?? true
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
}

private extension UIView {
    func hasScrollableHorizontalDescendant(at location: CGPoint, excluding excludedView: UIView) -> Bool {
        guard let hitView = hitTest(location, with: nil) else { return false }
        var current: UIView? = hitView
        while let view = current, view !== excludedView {
            if let scrollView = view as? UIScrollView,
               scrollView.isScrollEnabled,
               scrollView.panGestureRecognizer.isEnabled,
               scrollView.contentSize.width > scrollView.bounds.width + 1,
               scrollView.contentSize.width > scrollView.contentSize.height {
                return true
            }
            current = view.superview
        }
        return false
    }
}

private extension VideoDetailScreenSnapshot {
    func hash(into hasher: inout Hasher) {
        hasher.combine(videoCode)
        hasher.combine(title)
        hasher.combine(chineseTitle)
        hasher.combine(videoDescription)
        hasher.combine(views)
        hasher.combine(tagSummary)
        hasher.combine(sourceCount)
        hasher.combine(defaultSourceLabel)
        hasher.combine(defaultSourceUrl)
        hasher.combine(uploadDate)
        hasher.combine(coverUrl)
        hasher.combine(artist)
        hasher.combine(favTimes)
        hasher.combine(isFav)
        hasher.combine(csrfToken)
        hasher.combine(currentUserId)
        hasher.combine(isWatchLater)
        hasher.combine(originalComic)
        hasher.combine(playbackPositionMillis)
        hasher.combine(tags)
        hasher.combine(playbackSources)
        hasher.combine(playlistName)
        playlistVideos.forEach { $0.hash(into: &hasher) }
        hasher.combine(myListItems)
        relatedVideos.forEach { $0.hash(into: &hasher) }
    }
}

private extension VideoRelatedRow {
    func hash(into hasher: inout Hasher) {
        hasher.combine(videoCode)
        hasher.combine(title)
        hasher.combine(coverUrl)
        hasher.combine(duration)
        hasher.combine(views)
        hasher.combine(artist)
        hasher.combine(uploadTime)
        hasher.combine(isPlaying)
    }
}

struct TapOnlyControl<Label: View>: View {
    let isDisabled: Bool
    let action: () -> Void
    let label: () -> Label

    init(
        isDisabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isDisabled = isDisabled
        self.action = action
        self.label = label
    }

    var body: some View {
        label()
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDisabled else { return }
                action()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                guard !isDisabled else { return }
                action()
            }
    }
}

private struct AndroidStyleIntroduction: View {
    let snapshot: VideoDetailScreenSnapshot
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let isArtistActionRunning: Bool
    let onToggleArtistSubscription: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleWatchLater: () -> Void
    let onSetMyListItem: (VideoMyListRow, Bool) -> Void
    let onShowMessage: (String) -> Void
    let showsRelated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let artist = snapshot.artist {
                ArtistCard(
                    artist: artist,
                    isRunning: isArtistActionRunning,
                    toggleAction: onToggleArtistSubscription,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }

            TitleBlock(snapshot: snapshot)
            MetadataRow(snapshot: snapshot)

            if let description = snapshot.videoDescription, !description.isEmpty {
                ExpandableDescription(text: description)
            }

            ActionButtonRow(
                snapshot: snapshot,
                onToggleFavorite: onToggleFavorite,
                onToggleWatchLater: onToggleWatchLater,
                onSetMyListItem: onSetMyListItem,
                onShowMessage: onShowMessage,
                onDownload: { source in
                    DownloadManager.shared.enqueue(
                        videoCode: snapshot.videoCode,
                        quality: source.label,
                        title: snapshot.title,
                        coverUrl: snapshot.coverUrl,
                        remoteUrl: source.url
                    )
                    onShowMessage(String(localized: "已加入下载"))
                }
            )

            if !snapshot.tags.isEmpty {
                TagFlow(
                    tags: snapshot.tags,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }

            if !snapshot.playlistVideos.isEmpty {
                HorizontalVideoSection(
                    title: "系列影片",
                    subtitle: snapshot.playlistName,
                    videos: snapshot.playlistVideos,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature,
                    showPlaying: true,
                    showsMetadataFooter: false
                )
            }

            if showsRelated && !snapshot.relatedVideos.isEmpty {
                RelatedVideoGrid(
                    videos: snapshot.relatedVideos,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct ArtistCard: View {
    let artist: VideoArtistRow
    let isRunning: Bool
    let toggleAction: () -> Void
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    @Environment(\.searchFeature) private var searchFeature
    @State private var isConfirmingUnsubscribe = false
    @State private var isShowingArtistVideos = false

    var body: some View {
        HStack(spacing: 12) {
            // Artist avatar / name / genre — tap to push the artist's videos
            // page (NavigationLink). Subscription button to the right is
            // independent and remains tap-able while the rest of the card
            // navigates.
            artistInfoTappable

            Spacer()

            TapOnlyControl(isDisabled: isRunning) {
                if artist.isSubscribed {
                    isConfirmingUnsubscribe = true
                } else {
                    toggleAction()
                }
            } label: {

                Text(artist.isSubscribed ? "已订阅" : "订阅")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .confirmationDialog("取消订阅该作者", isPresented: $isConfirmingUnsubscribe) {
            Button("取消订阅", role: .destructive) {
                toggleAction()
            }
            Button("不取消", role: .cancel) {}
        } message: {
            Text("确定要取消订阅吗？")
        }
        .navigationDestination(isPresented: $isShowingArtistVideos) {
            if let searchFeature {
                ArtistVideosView(
                    artistName: artist.name,
                    searchFeature: searchFeature,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }
        }
    }

    /// Wraps the avatar + name + genre block in a NavigationLink that pushes
    /// the artist's video list. Falls back to a non-tappable label if the
    /// SearchFeature isn't available in the environment (shouldn't happen in
    /// production but keeps the view robust during previews / testing).
    @ViewBuilder
    private var artistInfoTappable: some View {
        if searchFeature != nil {
            TapOnlyControl {
                isShowingArtistVideos = true
            } label: {
                artistInfoLabel
            }
        } else {
            artistInfoLabel
        }
    }

    private var artistInfoLabel: some View {
        HStack(spacing: 12) {
            AsyncImage(url: artist.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.secondary.opacity(0.15))
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let genre = artist.genre, !genre.isEmpty {
                    Text(genre)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

private struct TitleBlock: View {
    let snapshot: VideoDetailScreenSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.chineseTitle?.isEmpty == false ? snapshot.chineseTitle! : snapshot.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            if let chineseTitle = snapshot.chineseTitle, !chineseTitle.isEmpty, chineseTitle != snapshot.title {
                Text(snapshot.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct MetadataRow: View {
    let snapshot: VideoDetailScreenSnapshot

    var body: some View {
        HStack(spacing: 8) {
            if let views = snapshot.views, !views.isEmpty {
                Text(String(format: String(localized: "video.views.count"), views))
            }
            if snapshot.views?.isEmpty == false && snapshot.uploadDate?.isEmpty == false {
                Divider()
                    .frame(height: 16)
            }
            if let uploadDate = snapshot.uploadDate, !uploadDate.isEmpty {
                Text(uploadDate)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

private struct ExpandableDescription: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(expanded ? nil : 4)
                .textSelection(.enabled)

            TapOnlyControl {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded.toggle()
                }
            } label: {
                Text(expanded ? String(localized: "收起") : String(localized: "展开"))
            }
            .font(.caption.weight(.semibold))
        }
    }
}

private struct ActionButtonRow: View {
    let snapshot: VideoDetailScreenSnapshot
    let onToggleFavorite: () -> Void
    let onToggleWatchLater: () -> Void
    let onSetMyListItem: (VideoMyListRow, Bool) -> Void
    let onShowMessage: (String) -> Void
    /// Invoked when the user picks a concrete quality to download.
    let onDownload: (VideoPlaybackSourceRow) -> Void
    @Environment(\.openURL) private var openURL
    @State private var isShowingMyList = false
    @State private var isShowingMoreActions = false
    @State private var isShowingShareSheet = false
    @State private var isShowingDownloadQuality = false

    private var videoURL: URL? {
        siteURL(path: "/watch")
    }

    private var downloadURL: URL? {
        siteURL(path: "/download")
    }

    /// Real downloadable sources (a concrete resolution + a usable URL).
    /// A lone "auto" source means the page only exposed a JS-extracted
    /// single URL with no resolution choices — in that case we fall back
    /// to opening the official download page instead of in-app download.
    private var downloadableSources: [VideoPlaybackSourceRow] {
        snapshot.playbackSources.filter { $0.label.uppercased() != "AUTO" && !$0.url.isEmpty }
    }

    private func siteURL(path: String) -> URL? {
        guard var components = URLComponents(string: AppDomain.currentBaseURL) else {
            return nil
        }
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "v", value: snapshot.videoCode)
        ]
        return components.url
    }

    var body: some View {
        HStack(spacing: 6) {
            LabelButton(
                title: snapshot.isFav ? "已收藏" : "收藏",
                systemImage: snapshot.isFav ? "heart.fill" : "heart",
                action: onToggleFavorite
            )

            LabelButton(
                title: snapshot.isWatchLater ? "已稍后" : "稍后观看",
                systemImage: "text.badge.plus",
                action: onToggleWatchLater
            )

            LabelButton(
                title: "更多",
                systemImage: "ellipsis.circle",
                action: {
                    isShowingMoreActions = true
                }
            )

            LabelButton(
                title: "分享",
                systemImage: "square.and.arrow.up",
                action: {
                    if videoURL != nil {
                        isShowingShareSheet = true
                    }
                }
            )
        }
        .confirmationDialog("更多操作", isPresented: $isShowingMoreActions, titleVisibility: .visible) {
            Button("加入列表") {
                if snapshot.myListItems.isEmpty {
                    onShowMessage(String(localized: "video.action.playlist.empty"))
                } else {
                    isShowingMyList = true
                }
            }

            Button("下载") {
                if downloadableSources.isEmpty {
                    // No selectable resolutions parsed — defer to the
                    // site's official download page in the browser.
                    if let downloadURL { openURL(downloadURL) }
                } else {
                    isShowingDownloadQuality = true
                }
            }

            if snapshot.originalComic?.isEmpty == false {
                Button("原作漫画") {
                    if let originalComic = snapshot.originalComic,
                       let url = URL(string: originalComic) {
                        openURL(url)
                    }
                }
            }

            Button("网页") {
                if let videoURL {
                    openURL(videoURL)
                }
            }

            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("播放列表", isPresented: $isShowingMyList) {
            ForEach(snapshot.myListItems) { item in
                Button(String(format: NSLocalizedString(item.isSelected ? "video.playlist.remove_item" : "video.playlist.add_item", comment: ""), item.title)) {
                    onSetMyListItem(item, !item.isSelected)
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let videoURL {
                ActivityView(activityItems: [videoURL])
            }
        }
        .confirmationDialog("选择下载画质", isPresented: $isShowingDownloadQuality, titleVisibility: .visible) {
            ForEach(downloadableSources) { source in
                Button(source.label) {
                    onDownload(source)
                }
            }
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        controller.popoverPresentationController?.sourceRect = CGRect(
            x: controller.view.bounds.midX,
            y: controller.view.bounds.midY,
            width: 0,
            height: 0
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LabelButton: View {
    let title: String
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        TapOnlyControl(action: action) {
            LabelButtonContent(title: title, systemImage: systemImage)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LabelButtonContent: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct TagFlow: View {
    let tags: [String]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    @Environment(\.searchFeature) private var searchFeature
    @State private var selectedTag: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.headline)
            // Custom Layout that flows tags onto each row according to their
            // measured width, wrapping when the next tag wouldn't fit. Avoids
            // the rigid grid look of LazyVGrid where every tag occupies the
            // same column width.
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                    if searchFeature != nil {
                        TapOnlyControl {
                            selectedTag = tag
                        } label: {
                            TagChipText(tag: tag)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                                )
                        }
                    } else {
                        // Defensive: if the search feature isn't injected (
                        // which shouldn't happen in production) the tag still
                        // renders as a disabled bordered chip rather than
                        // disappearing entirely.
                        TagChipText(tag: tag)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(.secondary)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedTag != nil },
                set: { if !$0 { selectedTag = nil } }
            )
        ) {
            if let selectedTag, let searchFeature {
                ArtistVideosView(
                    title: "#\(selectedTag)",
                    mode: .keyword(selectedTag),
                    searchFeature: searchFeature,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }
        }
    }
}

private struct TagChipText: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 240, alignment: .leading)
    }
}

/// Lightweight flow layout: lays out subviews left-to-right, wrapping to a
/// new line when a child wouldn't fit on the current one. Each child takes
/// its natural intrinsic width, so different-length labels pack tightly.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = arrange(in: maxWidth, subviews: subviews)
        // Report content size based on actually used width when proposal is
        // unbounded, otherwise fill the proposal so the parent can size us
        // consistently.
        let width: CGFloat
        if maxWidth.isFinite {
            width = maxWidth
        } else {
            width = result.usedWidth
        }
        return CGSize(width: width, height: result.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            let origin = CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y)
            subviews[index].place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private struct Arranged {
        let frames: [CGRect]
        let totalHeight: CGFloat
        let usedWidth: CGFloat
    }

    private func arrange(in maxWidth: CGFloat, subviews: Subviews) -> Arranged {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var maxRowEnd: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            // If this subview wouldn't fit on the current row, wrap.
            if x > 0 && x + size.width > maxWidth {
                y += currentRowHeight + lineSpacing
                x = 0
                currentRowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
            maxRowEnd = max(maxRowEnd, x - spacing)
        }

        let totalHeight = y + currentRowHeight
        return Arranged(frames: frames, totalHeight: totalHeight, usedWidth: maxRowEnd)
    }
}

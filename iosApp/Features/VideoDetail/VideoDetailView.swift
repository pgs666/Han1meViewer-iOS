import SwiftUI
import UIKit
import Han1meShared

struct VideoDetailView: View {
    let videoCode: String
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    @StateObject private var viewModel: VideoDetailViewModel
    @StateObject private var commentViewModel: CommentViewModel
    @State private var selectedTab = VideoPageTab.introduction
    @State private var isPlayerFullscreen = false
    @State private var pushedSeriesVideoCode: String?
    @State private var isPushingSeriesVideo = false
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
        content
            .logScreen("VideoDetail v=\(videoCode)")
            .navigationDestination(
                isPresented: $isPushingSeriesVideo
            ) {
                if let pushedSeriesVideoCode {
                    VideoDetailView(
                        videoCode: pushedSeriesVideoCode,
                        videoFeature: videoFeature,
                        commentFeature: commentFeature
                    )
                }
            }
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
            .ignoresSafeArea(edges: isPlayerFullscreen ? .all : [])
            .task {
                viewModel.loadIfNeeded(videoCode: videoCode)
            }
            .onDisappear {
                // KSPlayer pauses itself in its own .onDisappear; the
                // detail VM no longer owns a player.
                if isPlayerFullscreen {
                    AppOrientationController.shared.unlockAfterFullscreen()
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    if newValue {
                        AppOrientationController.shared.lockForFullscreen(to: fullscreenOrientation)
                    } else {
                        AppOrientationController.shared.unlockAfterFullscreen()
                    }
                }
            }
    }

    /// Decides whether the player should rotate to landscape or stay in
    /// portrait when entering fullscreen. Defaults to landscape (existing
    /// behaviour); switches to portrait only when both:
    /// 1. The video's reported natural size is taller than wide.
    /// 2. The user has the "force portrait fullscreen for vertical
    ///    videos" preference enabled (default ON).
    private var fullscreenOrientation: VideoFullscreenOrientation {
        let isPortraitVideo: Bool = {
            guard let size = videoNaturalSize else { return false }
            return size.height > size.width
        }()
        if isPortraitVideo && forcePortraitForVerticalVideos {
            return .portrait
        }
        return .landscape
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
                let isWide = horizontalSizeClass == .regular
                    && proxy.size.width >= 900
                    && proxy.size.width > proxy.size.height
                    && !isPlayerFullscreen
                let leftWidth: CGFloat = isWide
                    ? min(max(proxy.size.width * 0.64, 620), proxy.size.width - 360)
                    : proxy.size.width

                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        playerArea(snapshot: snapshot)
                            .frame(
                                width: leftWidth,
                                height: playerHeight(
                                    panelWidth: leftWidth,
                                    parentHeight: proxy.size.height
                                )
                            )

                        if !isPlayerFullscreen {
                            // showsRelated=false on iPad regular landscape because the
                            // dedicated right sidebar already shows related videos —
                            // duplicating them in the bottom scroll would be redundant.
                            belowPlayerPager(snapshot: snapshot, showsRelated: !isWide)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: leftWidth)

                    if isWide {
                        Divider()
                        TabletRelatedSidebar(
                            videos: snapshot.relatedVideos,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature,
                            coverLayout: snapshot.relatedVideosUsePortraitCovers ? .hanimePortrait : .landscape
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            // The parent TabView still reports the home-indicator safe area
            // after its tab bar has been hidden. Extend the detail layout —
            // not just its background — through that stale bottom inset so
            // the pager receives the full remaining screen height.
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    /// Player 高度：
    /// - 全屏：撑满整个父容器
    /// - inline：左 panel 宽度的 16:9（不再依赖父容器 height）
    private func playerHeight(panelWidth: CGFloat, parentHeight: CGFloat) -> CGFloat {
        if isPlayerFullscreen { return parentHeight }
        return panelWidth * 9 / 16
    }

    private func playerArea(snapshot: VideoDetailScreenSnapshot) -> some View {
        return KSPlayerView(
            snapshot: snapshot,
            isFullscreen: $isPlayerFullscreen,
            onProgress: { viewModel.recordPlaybackPosition(seconds: $0) },
            onPlaybackEnded: { viewModel.recordPlaybackPosition(seconds: 0) },
            onBack: { dismiss() },
            onNaturalSize: { size in
                videoNaturalSize = size
            }
        )
    }

    private func belowPlayerPager(snapshot: VideoDetailScreenSnapshot, showsRelated: Bool) -> some View {
        VStack(spacing: 0) {
            Picker("Content", selection: $selectedTab) {
                ForEach(VideoPageTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.background)

            Divider()

            detailPager(snapshot: snapshot, showsRelated: showsRelated)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func detailPager(snapshot: VideoDetailScreenSnapshot, showsRelated: Bool) -> some View {
        TabView(selection: $selectedTab) {
            ScrollView {
                AndroidStyleIntroduction(
                    snapshot: snapshot,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature,
                    isArtistActionRunning: viewModel.isActionRunning("artistSubscription"),
                    onToggleArtistSubscription: { viewModel.toggleArtistSubscription(snapshot: snapshot) },
                    onToggleFavorite: { viewModel.toggleFavorite(snapshot: snapshot) },
                    onToggleWatchLater: { viewModel.toggleWatchLater(snapshot: snapshot) },
                    onSetMyListItem: { item, isSelected in
                        viewModel.setMyListItem(snapshot: snapshot, item: item, isSelected: isSelected)
                    },
                    onShowMessage: { viewModel.showActionMessage($0) },
                    onOpenSeriesVideo: {
                        pushedSeriesVideoCode = $0
                        isPushingSeriesVideo = true
                    },
                    showsRelated: showsRelated
                )
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .refreshable {
                await viewModel.refresh(videoCode: videoCode)
            }
            .background(PagerEdgePopPriorityBridge())
            .tag(VideoPageTab.introduction)

            CommentView(viewModel: commentViewModel)
            .background(PagerEdgePopPriorityBridge())
            .tag(VideoPageTab.comments)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

}

private enum VideoPageTab: String, CaseIterable, Identifiable {
    case introduction
    case comments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .introduction:
            return String(localized: "简介")
        case .comments:
            return String(localized: "评论")
        }
    }
}

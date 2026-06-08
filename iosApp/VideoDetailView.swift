import SwiftUI
import UIKit
import Han1meShared

struct VideoDetailView: View {
    let videoCode: String
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    @StateObject private var viewModel: VideoDetailViewModel
    @State private var selectedTab = VideoPageTab.introduction
    @State private var isPlayerFullscreen = false
    @State private var isPlayerPlaying = false
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
    }

    var body: some View {
        content
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
            .ignoresSafeArea(edges: isPlayerFullscreen ? .all : [])
            .task {
                viewModel.loadIfNeeded(videoCode: videoCode)
            }
            .refreshable {
                // Refresh without the full-screen .loading spinner flash:
                // keep the current content visible while re-fetching. The
                // player is rebuilt on success (acceptable for an explicit
                // refresh); this just removes the abrupt blank-out.
                await viewModel.refresh(videoCode: videoCode)
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
            // - Slot 0: a ZStack (the "left panel") that keeps the player
            //   below a higher-level paging container.
            //   Player is ALWAYS kept at a stable tree position, so size-class flips
            //   never reparent it (which would
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
                    leftPanel(
                        snapshot: snapshot,
                        panelWidth: leftWidth,
                        panelHeight: proxy.size.height,
                        showsRelated: !isWide
                    )
                    .frame(width: leftWidth)

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

    private func leftPanel(
        snapshot: VideoDetailScreenSnapshot,
        panelWidth: CGFloat,
        panelHeight: CGFloat,
        showsRelated: Bool
    ) -> some View {
        let currentPlayerHeight = playerHeight(panelWidth: panelWidth, parentHeight: panelHeight)
        let allowsVideoOverlay = !isPlayerPlaying
        let pagingTopOffset = allowsVideoOverlay ? 0 : currentPlayerHeight
        let pagingHeight = max(0, panelHeight - pagingTopOffset)
        let pagingTopInset = allowsVideoOverlay ? currentPlayerHeight : 0
        let pagingMinimumHitY = allowsVideoOverlay ? currentPlayerHeight : 0

        return ZStack(alignment: .top) {
            playerArea(snapshot: snapshot)
                .frame(width: panelWidth, height: currentPlayerHeight)
                .zIndex(0)

            if !isPlayerFullscreen {
                TopPassthroughContainer(minimumHitY: pagingMinimumHitY) {
                    pagingLayer(
                        snapshot: snapshot,
                        topInset: pagingTopInset,
                        showsRelated: showsRelated
                    )
                }
                .frame(width: panelWidth, height: pagingHeight)
                .offset(y: pagingTopOffset)
                .zIndex(1)
                .animation(.easeInOut(duration: 0.25), value: isPlayerPlaying)
            }
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
    }

    /// Player 高度：全屏撑满父容器，inline 固定为左 panel 宽度的 16:9。
    private func playerHeight(panelWidth: CGFloat, parentHeight: CGFloat) -> CGFloat {
        if isPlayerFullscreen { return parentHeight }
        return panelWidth * 9 / 16
    }

    private func playerArea(snapshot: VideoDetailScreenSnapshot) -> some View {
        KSPlayerView(
            snapshot: snapshot,
            isFullscreen: $isPlayerFullscreen,
            onProgress: { viewModel.recordPlaybackPosition(seconds: $0) },
            onPlaybackEnded: { viewModel.recordPlaybackPosition(seconds: 0) },
            onPlayingChanged: { newValue in
                guard isPlayerPlaying != newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPlayerPlaying = newValue
                }
            },
            onBack: { dismiss() },
            onNaturalSize: { size in
                videoNaturalSize = size
            }
        )
    }

    private func pagingLayer(
        snapshot: VideoDetailScreenSnapshot,
        topInset: CGFloat,
        showsRelated: Bool
    ) -> some View {
        TabView(selection: $selectedTab) {
            pagingScroll(topInset: topInset) {
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
            }
            .tag(VideoPageTab.introduction)

            pagingScroll(topInset: topInset) {
                CommentView(videoCode: videoCode, commentFeature: commentFeature)
            }
            .tag(VideoPageTab.comments)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func pagingScroll<Content: View>(
        topInset: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Color.clear
                    .frame(height: topInset)

                Section {
                    content()
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGroupedBackground))
                } header: {
                    pagingTabBar
                }
            }
        }
    }

    private var pagingTabBar: some View {
        Picker("Content", selection: $selectedTab) {
            ForEach(VideoPageTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.background)
        .frame(height: VideoPagingMetrics.tabBarHeight)
    }
}

private enum VideoPagingMetrics {
    static let tabBarHeight: CGFloat = 48
}

private struct TopPassthroughContainer<Content: View>: UIViewControllerRepresentable {
    let minimumHitY: CGFloat
    let content: Content

    init(minimumHitY: CGFloat, @ViewBuilder content: () -> Content) {
        self.minimumHitY = minimumHitY
        self.content = content()
    }

    func makeUIViewController(context: Context) -> PassthroughContainerController<Content> {
        let controller = PassthroughContainerController(rootView: content)
        controller.minimumHitY = minimumHitY
        return controller
    }

    func updateUIViewController(_ controller: PassthroughContainerController<Content>, context: Context) {
        controller.rootView = content
        controller.minimumHitY = minimumHitY
    }
}

private final class PassthroughContainerController<Content: View>: UIViewController {
    private let hostingController: UIHostingController<Content>

    var minimumHitY: CGFloat = 0 {
        didSet {
            passthroughView.minimumHitYProvider = { [weak self] in self?.minimumHitY ?? 0 }
        }
    }

    var rootView: Content {
        get { hostingController.rootView }
        set { hostingController.rootView = newValue }
    }

    private var passthroughView: TopPassthroughHostingView {
        view as! TopPassthroughHostingView
    }

    init(rootView: Content) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TopPassthroughHostingView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        passthroughView.minimumHitYProvider = { [weak self] in self?.minimumHitY ?? 0 }

        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
}

private final class TopPassthroughHostingView: UIView {
    var minimumHitYProvider: () -> CGFloat = { 0 }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard point.y >= minimumHitYProvider() else { return nil }
        return super.hitTest(point, with: event)
    }
}

private enum VideoPageTab: String, CaseIterable, Identifiable, Hashable {
    case introduction
    case comments

    var id: String { rawValue }

    var scrollCoordinateSpaceName: String {
        "videoPageScroll-\(rawValue)"
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
        LazyVStack(alignment: .leading, spacing: 16) {
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
                    showPlaying: true
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

    var body: some View {
        HStack(spacing: 12) {
            // Artist avatar / name / genre — tap to push the artist's videos
            // page (NavigationLink). Subscription button to the right is
            // independent and remains tap-able while the rest of the card
            // navigates.
            artistInfoTappable

            Spacer()

            Button {
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
            .disabled(isRunning)
            .buttonStyle(.plain)
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
    }

    /// Wraps the avatar + name + genre block in a NavigationLink that pushes
    /// the artist's video list. Falls back to a non-tappable label if the
    /// SearchFeature isn't available in the environment (shouldn't happen in
    /// production but keeps the view robust during previews / testing).
    @ViewBuilder
    private var artistInfoTappable: some View {
        if let searchFeature {
            NavigationLink {
                ArtistVideosView(
                    artistName: artist.name,
                    searchFeature: searchFeature,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            } label: {
                artistInfoLabel
            }
            .buttonStyle(.plain)
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

            Button(expanded ? String(localized: "收起") : String(localized: "展开")) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded.toggle()
                }
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
        Button(action: action) {
            LabelButtonContent(title: title, systemImage: systemImage)
        }
        .buttonStyle(.borderless)
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
                    if let searchFeature {
                        NavigationLink {
                            ArtistVideosView(
                                title: "#\(tag)",
                                mode: .keyword(tag),
                                searchFeature: searchFeature,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature
                            )
                        } label: {
                            Text(tag).font(.caption)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        // Defensive: if the search feature isn't injected (
                        // which shouldn't happen in production) the tag still
                        // renders as a disabled bordered chip rather than
                        // disappearing entirely.
                        Button(tag) { /* no-op */ }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .disabled(true)
                    }
                }
            }
        }
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

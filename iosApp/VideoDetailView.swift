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
    @State private var isPlayerCollapsed = false
    /// True iff the player is currently playing (not paused / buffering).
    /// Driven from KSPlayerView via the @Binding below. Used to lock the
    /// player at full 16:9 height while playing — only paused state lets the
    /// scroll-driven shrink behaviour engage.
    @State private var isPlayerPlaying = false
    /// Vertical scroll offset of the inline content area below the player,
    /// measured from the natural top (>= 0). When the user scrolls UP (so
    /// the offset grows), and the player is paused, the player shrinks
    /// proportionally — Bilibili-style "follow finger" collapse.
    @State private var bottomScrollOffset: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(videoCode: String, videoFeature: VideoFeature, commentFeature: CommentFeature) {
        self.videoCode = videoCode
        self.videoFeature = videoFeature
        self.commentFeature = commentFeature
        _viewModel = StateObject(wrappedValue: VideoDetailViewModel(videoFeature: videoFeature))
    }

    var body: some View {
        content
            .navigationTitle("详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isPlayerFullscreen ? .hidden : .visible, for: .navigationBar)
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
                viewModel.load(videoCode: videoCode)
            }
            .onDisappear {
                viewModel.pausePlayer()
                if isPlayerFullscreen {
                    AppOrientationController.shared.unlockAfterFullscreen()
                }
            }
            .alert(item: $viewModel.actionMessage) { message in
                Alert(title: Text(message.message))
            }
            .onValueChange(of: isPlayerFullscreen) { newValue in
                if newValue {
                    AppOrientationController.shared.lockForFullscreen(to: .landscape)
                } else {
                    AppOrientationController.shared.unlockAfterFullscreen()
                }
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
                            belowPlayerScroll(snapshot: snapshot, showsRelated: !isWide)
                        }
                    }
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

    /// Player 高度：
    /// - 全屏：撑满整个父容器
    /// - 折叠：50pt 标题 strip
    /// - inline：左 panel 宽度的 16:9（不再依赖父容器 height）
    private func playerHeight(panelWidth: CGFloat, parentHeight: CGFloat) -> CGFloat {
        if isPlayerFullscreen { return parentHeight }
        if isPlayerCollapsed { return 50 }
        let baseHeight = panelWidth * 9 / 16
        // While playing, lock to full 16:9 — never shrink with scroll.
        if isPlayerPlaying { return baseHeight }
        // Paused: follow the user's scroll. As bottomScrollOffset grows
        // (content scrolled up), the player shrinks proportionally, never
        // below playerCollapsedFollowMinHeight so its overlay controls
        // remain at least partly visible.
        let minHeight: CGFloat = max(baseHeight * 0.32, 80)
        let shrink = max(0, min(baseHeight - minHeight, bottomScrollOffset))
        return baseHeight - shrink
    }

    private func playerArea(snapshot: VideoDetailScreenSnapshot) -> some View {
        KSPlayerView(
            snapshot: snapshot,
            isFullscreen: $isPlayerFullscreen,
            isCollapsed: $isPlayerCollapsed,
            onProgress: { viewModel.recordPlaybackPosition(seconds: $0) },
            onPlaybackEnded: { viewModel.recordPlaybackPosition(seconds: 0) },
            onPlayingChanged: { newValue in
                if isPlayerPlaying != newValue {
                    isPlayerPlaying = newValue
                }
            }
        )
    }

    private func belowPlayerScroll(snapshot: VideoDetailScreenSnapshot, showsRelated: Bool) -> some View {
        ScrollView {
            // Sentinel GeometryReader at the top of the scrollable content.
            // Its frame.minY in the named "bottomScroll" coordinate space
            // tracks the scroll offset directly: scroll up by 100pt and
            // proxy.frame(in:).minY becomes -100 (because the sentinel
            // physically moves up inside the ScrollView's fixed viewport).
            // We negate so the published value grows positive as the user
            // scrolls up, matching the player-shrink direction.
            GeometryReader { proxy in
                Color.clear.preference(
                    key: BottomScrollOffsetPreferenceKey.self,
                    value: -proxy.frame(in: .named("bottomScroll")).minY
                )
            }
            .frame(height: 0)

            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                Section {
                    // Wrap the per-tab content in a Group with .id(selectedTab)
                    // so SwiftUI treats the two branches as distinct view
                    // identities. Without this, switching introduction →
                    // comments inside a LazyVStack section sometimes
                    // recycles the row and leaves contentSize stale, which
                    // showed as a blank page until the user nudged the
                    // ScrollView (re-laying out and refreshing the size).
                    Group {
                        switch selectedTab {
                        case .introduction:
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
                        case .comments:
                            CommentView(videoCode: videoCode, commentFeature: commentFeature)
                        }
                    }
                    .id(selectedTab)
                } header: {
                    Picker("Content", selection: $selectedTab) {
                        ForEach(VideoPageTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.background)
                }
            }
            .padding(.bottom, 24)
        }
        .coordinateSpace(name: "bottomScroll")
        .onPreferenceChange(BottomScrollOffsetPreferenceKey.self) { value in
            // Clamp to >= 0 — over-pull at the top should not expand the
            // player past 16:9.
            bottomScrollOffset = max(0, value)
        }
    }
}

/// Reports the inline-content ScrollView's vertical offset from its top so
/// the player area can shrink (B-station-style) when the user scrolls up
/// while paused. Reduce policy: keep the largest reported value of a single
/// pass — there's only one ScrollView publishing into this key.
private struct BottomScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
                onShowMessage: onShowMessage
            )

            if !snapshot.tags.isEmpty {
                TagFlow(tags: snapshot.tags)
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
    @Environment(\.openURL) private var openURL
    @State private var isShowingMyList = false
    @State private var isShowingShareSheet = false

    private var videoURL: URL? {
        URL(string: "https://hanime1.me/watch?v=\(snapshot.videoCode)")
    }

    private var downloadURL: URL? {
        URL(string: "https://hanime1.me/download?v=\(snapshot.videoCode)")
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
                    title: "加入列表",
                    systemImage: "list.bullet",
                    action: {
                        if snapshot.myListItems.isEmpty {
                            onShowMessage(String(localized: "video.action.playlist.empty"))
                        } else {
                            isShowingMyList = true
                        }
                    }
                )

                LabelButton(
                    title: "下载",
                    systemImage: "arrow.down.circle",
                    action: {
                        if let downloadURL {
                            openURL(downloadURL)
                        }
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

                if snapshot.originalComic?.isEmpty == false {
                    LabelButton(
                        title: "原作漫画",
                        systemImage: "book",
                        action: {
                            if let originalComic = snapshot.originalComic,
                               let url = URL(string: originalComic) {
                                openURL(url)
                            }
                        }
                    )
                }

                LabelButton(
                    title: "网页",
                    systemImage: "safari",
                    action: {
                        if let videoURL {
                            openURL(videoURL)
                        }
                    }
                )
            }
            .padding(.horizontal, 2)
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
        .frame(minWidth: 76)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct TagFlow: View {
    let tags: [String]

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
                    Button(tag) {
                        SearchNavigationCenter.open(keyword: tag)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
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

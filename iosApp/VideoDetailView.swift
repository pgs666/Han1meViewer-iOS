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
            .toolbar(isPlayerFullscreen ? .hidden : .visible, for: .tabBar)
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
            // KEY: keep KSPlayerView at a stable SwiftUI tree position. The
            // GeometryReader wraps the WHOLE loaded layout, but playerArea is
            // ALWAYS the first child of the inner VStack — never inside the
            // if/else that switches phone vs tablet bottom layout. So when
            // size class flips (e.g. iPad rotates into landscape regular),
            // only the bottom branch remounts; the player keeps its identity,
            // its @StateObject Coordinator, and its KSPlayerLayer → no reload.
            //
            // Using explicit .frame(width:height:) instead of .aspectRatio(_:.fit)
            // because aspectRatio fit inside a VStack picks the height-limited
            // dimension when the bottom subview also wants vertical space, which
            // shrank the player to ~50% width on iPad and exposed the black
            // systemGroupedBackground on both sides.
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    playerArea(snapshot: snapshot)
                        .frame(width: proxy.size.width, height: playerHeight(in: proxy.size))

                    if !isPlayerFullscreen {
                        if horizontalSizeClass == .regular && proxy.size.width >= 900 {
                            tabletBottomContent(snapshot: snapshot, size: proxy.size)
                        } else {
                            phoneBottomContent(snapshot: snapshot)
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    /// Player 高度：
    /// - 全屏：撑满整个父容器
    /// - 折叠：50pt 标题 strip
    /// - iPad regular 横屏：取 min(16:9-by-width, 0.65 × parent height)；避免 16:9
    ///   全宽吃光下方 split 内容空间
    /// - 其他：16:9 by full width（手机 / iPad 竖屏）
    private func playerHeight(in size: CGSize) -> CGFloat {
        if isPlayerFullscreen { return size.height }
        if isPlayerCollapsed { return 50 }
        let isWideLayout = horizontalSizeClass == .regular && size.width >= 900
        if isWideLayout {
            return min(size.width * 9 / 16, size.height * 0.65)
        }
        return size.width * 9 / 16
    }

    /// Phone / iPad compact / iPad portrait: 单一 ScrollView 占据 player 下方全部空间。
    private func phoneBottomContent(snapshot: VideoDetailScreenSnapshot) -> some View {
        belowPlayerScroll(snapshot: snapshot, showsRelated: true)
    }

    /// iPad regular landscape (split layout below the top-pinned player):
    /// 左主 scroll + 右相关视频 sidebar。
    private func tabletBottomContent(snapshot: VideoDetailScreenSnapshot, size: CGSize) -> some View {
        let leftWidth = min(max(size.width * 0.64, 620), size.width - 360)
        return HStack(alignment: .top, spacing: 0) {
            belowPlayerScroll(snapshot: snapshot, showsRelated: false)
                .frame(width: leftWidth)

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

    private func playerArea(snapshot: VideoDetailScreenSnapshot) -> some View {
        KSPlayerView(
            snapshot: snapshot,
            isFullscreen: $isPlayerFullscreen,
            isCollapsed: $isPlayerCollapsed,
            onProgress: { viewModel.recordPlaybackPosition(seconds: $0) },
            onPlaybackEnded: { viewModel.recordPlaybackPosition(seconds: 0) }
        )
    }

    private func belowPlayerScroll(snapshot: VideoDetailScreenSnapshot, showsRelated: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                Section {
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
                    toggleAction: onToggleArtistSubscription
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
    @State private var isConfirmingUnsubscribe = false

    var body: some View {
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
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

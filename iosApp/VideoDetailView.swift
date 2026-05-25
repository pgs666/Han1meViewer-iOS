import AVKit
import SwiftUI
import UIKit
import Han1meShared

struct VideoDetailView: View {
    let videoCode: String
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    @StateObject private var viewModel: VideoDetailViewModel
    @State private var selectedTab = VideoPageTab.introduction
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
            .task {
                viewModel.loadIfNeeded(videoCode: videoCode)
            }
            .refreshable {
                viewModel.load(videoCode: videoCode)
            }
            .onDisappear {
                viewModel.pausePlayer()
            }
            .alert(item: $viewModel.actionMessage) { message in
                Alert(title: Text(message.message))
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
            GeometryReader { proxy in
                if horizontalSizeClass == .regular && proxy.size.width >= 900 {
                    tabletContent(snapshot: snapshot, size: proxy.size)
                } else {
                    ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    AndroidStylePlayerHeader(snapshot: snapshot, viewModel: viewModel)

                    Section {
                        switch selectedTab {
                        case .introduction:
                            AndroidStyleIntroduction(
                                snapshot: snapshot,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature,
                                viewModel: viewModel,
                                showsRelated: true
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
            .background(Color(.systemGroupedBackground))
        }
    }

    private func tabletContent(snapshot: VideoDetailScreenSnapshot, size: CGSize) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    AndroidStylePlayerHeader(snapshot: snapshot, viewModel: viewModel)

                    Section {
                        switch selectedTab {
                        case .introduction:
                            AndroidStyleIntroduction(
                                snapshot: snapshot,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature,
                                viewModel: viewModel,
                                showsRelated: false
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
            .frame(width: min(max(size.width * 0.64, 620), size.width - 360))

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

private struct AndroidStylePlayerHeader: View {
    let snapshot: VideoDetailScreenSnapshot
    @ObservedObject var viewModel: VideoDetailViewModel
    @State private var isShowingFullscreen = false

    var body: some View {
        VStack(spacing: 0) {
            playerSurface
                .frame(maxWidth: .infinity)
                .background(Color.black)

            if !snapshot.playbackSources.isEmpty {
                VStack(spacing: 10) {
                    Picker("清晰度", selection: $viewModel.selectedPlaybackSourceID) {
                        ForEach(snapshot.playbackSources) { source in
                            Text(source.label).tag(source.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    playbackRatePicker
                }
                .padding(12)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            viewModel.preparePlayer(snapshot: snapshot)
        }
        .onValueChange(of: viewModel.selectedPlaybackSourceID) { sourceID in
            viewModel.selectPlaybackSource(snapshot: snapshot, sourceID: sourceID)
        }
        .fullScreenCover(isPresented: $isShowingFullscreen, onDismiss: {
            AppOrientationController.shared.enforceCurrentOrientationMask()
        }) {
            FullscreenVideoPlayer(
                title: snapshot.title,
                player: viewModel.player,
                onClose: {
                    isShowingFullscreen = false
                }
            )
        }
    }

    private var playerSurface: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                AsyncImage(url: snapshot.coverURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.black)
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "play.slash")
                            .font(.title)
                        Text("未解析到可播放源")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                }
            }

            if viewModel.player != nil {
                Button {
                    isShowingFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.48), in: Circle())
                }
                .padding(12)
                .accessibilityLabel("全屏播放")
            }
        }
    }

    private var playbackRatePicker: some View {
        HStack(spacing: 10) {
            Text(String(localized: "video.playback.speed"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker(
                String(localized: "video.playback.speed"),
                selection: Binding(
                    get: { viewModel.selectedPlaybackRate },
                    set: { viewModel.selectPlaybackRate($0) }
                )
            ) {
                ForEach(viewModel.playbackRates, id: \.self) { rate in
                    Text(playbackRateLabel(rate)).tag(rate)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func playbackRateLabel(_ rate: Float) -> String {
        var label = String(format: "%.2f", rate)
        while label.contains(".") && label.last == "0" {
            label.removeLast()
        }
        if label.last == "." {
            label.removeLast()
        }
        return "\(label)x"
    }
}

private struct FullscreenVideoPlayer: View {
    let title: String
    let player: AVPlayer?
    let onClose: () -> Void
    @StateObject private var metrics = FullscreenVideoMetrics()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player {
                GeometryReader { proxy in
                    VideoPlayer(player: player)
                        .aspectRatio(metrics.aspectRatio, contentMode: .fit)
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .center
                        )
                }
                .ignoresSafeArea()
            } else {
                Text("未解析到可播放源")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.52), in: Circle())
                }
                .accessibilityLabel("退出全屏")

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .onAppear {
            metrics.start(player: player)
            AppOrientationController.shared.lockForFullscreen(to: metrics.orientation)
        }
        .onValueChange(of: metrics.orientation) { orientation in
            AppOrientationController.shared.lockForFullscreen(to: orientation)
        }
        .onDisappear {
            metrics.stop()
            AppOrientationController.shared.unlockAfterFullscreen()
        }
    }
}

@MainActor
private final class FullscreenVideoMetrics: ObservableObject {
    @Published private(set) var orientation: VideoFullscreenOrientation = .landscape
    @Published private(set) var aspectRatio: CGFloat = 16.0 / 9.0

    private var presentationSizeObservation: NSKeyValueObservation?

    func start(player: AVPlayer?) {
        stop()
        guard let item = player?.currentItem else {
            return
        }

        update(size: item.presentationSize)
        presentationSizeObservation = item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.update(size: item.presentationSize)
            }
        }
    }

    func stop() {
        presentationSizeObservation?.invalidate()
        presentationSizeObservation = nil
    }

    private func update(size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            return
        }

        aspectRatio = size.width / size.height
        orientation = size.width >= size.height ? .landscape : .portrait
    }
}

private struct AndroidStyleIntroduction: View {
    let snapshot: VideoDetailScreenSnapshot
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    @ObservedObject var viewModel: VideoDetailViewModel
    let showsRelated: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if let artist = snapshot.artist {
                ArtistCard(
                    artist: artist,
                    isRunning: viewModel.isActionRunning("artistSubscription"),
                    toggleAction: {
                        viewModel.toggleArtistSubscription(snapshot: snapshot)
                    }
                )
            }

            TitleBlock(snapshot: snapshot)
            MetadataRow(snapshot: snapshot)

            if let description = snapshot.videoDescription, !description.isEmpty {
                ExpandableDescription(text: description)
            }

            ActionButtonRow(snapshot: snapshot, viewModel: viewModel)

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
    @ObservedObject var viewModel: VideoDetailViewModel
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
                    action: {
                        viewModel.toggleFavorite(snapshot: snapshot)
                    }
                )

                LabelButton(
                    title: snapshot.isWatchLater ? "已稍后" : "稍后观看",
                    systemImage: "text.badge.plus",
                    action: {
                        viewModel.toggleWatchLater(snapshot: snapshot)
                    }
                )

                LabelButton(
                    title: "加入列表",
                    systemImage: "list.bullet",
                    action: {
                        if snapshot.myListItems.isEmpty {
                            viewModel.showActionMessage(String(localized: "video.action.playlist.empty"))
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
                    viewModel.setMyListItem(snapshot: snapshot, item: item, isSelected: !item.isSelected)
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


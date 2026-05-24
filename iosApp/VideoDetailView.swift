import AVKit
import SwiftUI
import Han1meShared

struct VideoDetailView: View {
    let videoCode: String
    private let videoFeature: VideoFeature
    @StateObject private var viewModel: VideoDetailViewModel
    @State private var selectedTab = VideoPageTab.introduction

    init(videoCode: String, videoFeature: VideoFeature) {
        self.videoCode = videoCode
        self.videoFeature = videoFeature
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    AndroidStylePlayerHeader(snapshot: snapshot)

                    Section {
                        switch selectedTab {
                        case .introduction:
                            AndroidStyleIntroduction(
                                snapshot: snapshot,
                                videoFeature: videoFeature
                            )
                        case .comments:
                            AndroidStyleCommentsPlaceholder()
                        }
                    } header: {
                        Picker("内容", selection: $selectedTab) {
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
            .background(Color(.systemGroupedBackground))
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
            return "简介"
        case .comments:
            return "评论"
        }
    }
}

private struct AndroidStylePlayerHeader: View {
    let snapshot: VideoDetailScreenSnapshot
    @State private var selectedSourceID: String
    @State private var player: AVPlayer?
    @State private var isShowingFullscreen = false

    init(snapshot: VideoDetailScreenSnapshot) {
        self.snapshot = snapshot
        let defaultSource = snapshot.playbackSources.first { $0.isDefault } ?? snapshot.playbackSources.first
        _selectedSourceID = State(initialValue: defaultSource?.id ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            playerSurface
                .frame(maxWidth: .infinity)
                .background(Color.black)

            if !snapshot.playbackSources.isEmpty {
                Picker("清晰度", selection: $selectedSourceID) {
                    ForEach(snapshot.playbackSources) { source in
                        Text(source.label).tag(source.id)
                    }
                }
                .pickerStyle(.segmented)
                .padding(12)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            configurePlayer(preservePosition: false)
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: selectedSourceID) { _ in
            configurePlayer(preservePosition: true)
        }
        .fullScreenCover(isPresented: $isShowingFullscreen) {
            FullscreenVideoPlayer(
                title: snapshot.title,
                player: player,
                onClose: {
                    isShowingFullscreen = false
                }
            )
        }
    }

    private var selectedSource: VideoPlaybackSourceRow? {
        snapshot.playbackSources.first { $0.id == selectedSourceID } ?? snapshot.playbackSources.first
    }

    private var playerSurface: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player {
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

            if player != nil {
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

    private func configurePlayer(preservePosition: Bool) {
        guard let source = selectedSource, let url = URL(string: source.url) else {
            player = nil
            return
        }

        let previousPlayer = player
        let previousTime = preservePosition ? previousPlayer?.currentTime() : nil
        let shouldResume = previousPlayer?.timeControlStatus == .playing
        let nextPlayer = AVPlayer(url: url)
        player = nextPlayer

        if let previousTime {
            nextPlayer.seek(to: previousTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                if shouldResume {
                    nextPlayer.play()
                }
            }
        } else if shouldResume {
            nextPlayer.play()
        }
    }
}

private struct FullscreenVideoPlayer: View {
    let title: String
    let player: AVPlayer?
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
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
    }
}

private struct AndroidStyleIntroduction: View {
    let snapshot: VideoDetailScreenSnapshot
    let videoFeature: VideoFeature

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if let artist = snapshot.artist {
                ArtistCard(artist: artist)
            }

            TitleBlock(snapshot: snapshot)
            MetadataRow(snapshot: snapshot)

            if let description = snapshot.videoDescription, !description.isEmpty {
                ExpandableDescription(text: description)
            }

            ActionButtonRow(snapshot: snapshot)

            if !snapshot.tags.isEmpty {
                TagFlow(tags: snapshot.tags)
            }

            if !snapshot.playlistVideos.isEmpty {
                HorizontalVideoSection(
                    title: "系列影片",
                    subtitle: snapshot.playlistName,
                    videos: snapshot.playlistVideos,
                    videoFeature: videoFeature,
                    showPlaying: true
                )
            }

            if !snapshot.relatedVideos.isEmpty {
                RelatedVideoGrid(
                    videos: snapshot.relatedVideos,
                    videoFeature: videoFeature
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct ArtistCard: View {
    let artist: VideoArtistRow

    var body: some View {
        Button {} label: {
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

                Text(artist.isSubscribed ? "已订阅" : "订阅")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
                Text("\(views) 次观看")
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

            Button(expanded ? "收起" : "展开") {
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                LabelButton(
                    title: snapshot.isFav ? "已收藏" : "收藏",
                    systemImage: snapshot.isFav ? "heart.fill" : "heart"
                )

                LabelButton(
                    title: snapshot.isWatchLater ? "已稍后" : "稍后观看",
                    systemImage: "text.badge.plus"
                )

                LabelButton(
                    title: "加入列表",
                    systemImage: "list.bullet"
                )

                LabelButton(
                    title: "下载",
                    systemImage: "arrow.down.circle"
                )

                LabelButton(
                    title: "分享",
                    systemImage: "square.and.arrow.up"
                )

                if snapshot.originalComic?.isEmpty == false {
                    LabelButton(
                        title: "原作漫画",
                        systemImage: "book"
                    )
                }

                LabelButton(
                    title: "网页",
                    systemImage: "safari"
                )
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct LabelButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        Button {} label: {
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
        .buttonStyle(.borderless)
    }
}

private struct TagFlow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button(tag) {}
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct HorizontalVideoSection: View {
    let title: String
    let subtitle: String?
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let showPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("更多") {}
                    .font(.caption.weight(.semibold))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(videos) { video in
                        NavigationLink {
                            VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature)
                        } label: {
                            RelatedVideoCard(video: video, showPlaying: showPlaying)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct RelatedVideoGrid: View {
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("相关影片")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                ForEach(videos) { video in
                    NavigationLink {
                        VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature)
                    } label: {
                        RelatedVideoCard(video: video, showPlaying: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RelatedVideoCard: View {
    let video: VideoRelatedRow
    let showPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: video.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                }
                .frame(height: 96)
                .clipped()

                if showPlaying && video.isPlaying {
                    Text("正在播放")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(video.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if !video.metadata.isEmpty {
                Text(video.metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 172, alignment: .leading)
    }
}

private struct AndroidStyleCommentsPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("评论功能待迁移")
                .font(.headline)
            Text("安卓版这里是评论列表、回复、排序和举报入口。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private extension VideoDetailScreenSnapshot {
    var coverURL: URL? {
        coverUrl.flatMap(URL.init(string:))
    }
}

private extension VideoArtistRow {
    var avatarURL: URL? {
        avatarUrl.flatMap(URL.init(string:))
    }
}

private extension VideoRelatedRow {
    var coverURL: URL? {
        coverUrl.flatMap(URL.init(string:))
    }
}

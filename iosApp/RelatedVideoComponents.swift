import SwiftUI
import Han1meShared

struct HorizontalVideoSection: View {
    let title: String
    let subtitle: String?
    let videos: [VideoRelatedRow]
    let showPlaying: Bool
    let onOpenVideo: (String) -> Void

    @State private var isShowingAllVideos = false
    @State private var pendingVideoCode: String?
    @State private var isSelectionPending = false

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
                Button {
                    isShowingAllVideos = true
                } label: {
                    Text("更多")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityLabel(Text("查看全部\(title)"))
                .accessibilityValue(Text("共 \(videos.count) 部影片"))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(videos) { video in
                        Button {
                            openVideoIfNeeded(video)
                        } label: {
                            RelatedVideoCard(video: video, showPlaying: showPlaying)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAllVideos, onDismiss: openPendingVideo) {
            SeriesVideosSheet(
                title: title,
                videos: videos,
                showPlaying: showPlaying,
                onSelectVideo: selectVideo
            )
            .presentationDragIndicator(.visible)
        }
    }

    private func openVideoIfNeeded(_ video: VideoRelatedRow) {
        guard !showPlaying || !video.isPlaying else { return }
        onOpenVideo(video.videoCode)
    }

    private func selectVideo(_ videoCode: String) {
        guard !isSelectionPending else { return }
        isSelectionPending = true

        if showPlaying,
           videos.first(where: { $0.videoCode == videoCode })?.isPlaying == true {
            isShowingAllVideos = false
            return
        }

        pendingVideoCode = videoCode
        isShowingAllVideos = false
    }

    private func openPendingVideo() {
        isSelectionPending = false
        guard let videoCode = pendingVideoCode else { return }
        pendingVideoCode = nil
        onOpenVideo(videoCode)
    }
}

private struct SeriesVideosSheet: View {
    let title: String
    let videos: [VideoRelatedRow]
    let showPlaying: Bool
    let onSelectVideo: (String) -> Void

    var body: some View {
        CompatibleNavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(videos) { video in
                        Button {
                            onSelectVideo(video.videoCode)
                        } label: {
                            TabletRelatedVideoRow(
                                video: video,
                                showPlaying: showPlaying
                            )
                            .accessibilityElement(children: .combine)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 156)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct RelatedVideoGrid: View {
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let coverLayout: VideoCoverLayout

    private var columns: [GridItem] {
        let count = coverLayout == .hanimePortrait ? 3 : 2
        return Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("相关影片")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(videos) { video in
                    NavigationLink {
                        VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                    } label: {
                        RelatedVideoCard(
                            video: video,
                            showPlaying: false,
                            coverLayout: coverLayout,
                            expandsToFillWidth: true
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct TabletRelatedSidebar: View {
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let coverLayout: VideoCoverLayout

    var body: some View {
        ScrollView {
            Text("相关影片")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            if coverLayout == .hanimePortrait {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 2),
                    spacing: 12
                ) {
                    ForEach(videos) { video in
                        NavigationLink {
                            VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                        } label: {
                            RelatedVideoCard(
                                video: video,
                                showPlaying: false,
                                coverLayout: .hanimePortrait,
                                expandsToFillWidth: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(videos) { video in
                        NavigationLink {
                            VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                        } label: {
                            TabletRelatedVideoRow(video: video)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 156)
                    }
                }
            }
        }
        .padding(.bottom, 24)
    }
}

struct TabletRelatedVideoRow: View {
    let video: VideoRelatedRow
    let showPlaying: Bool

    init(video: VideoRelatedRow, showPlaying: Bool = false) {
        self.video = video
        self.showPlaying = showPlaying
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VideoCardCover(
                urlString: video.coverUrl,
                resizeWidth: 128,
                layout: .landscape,
                cornerRadius: 8
            ) {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if showPlaying && video.isPlaying {
                            Text("正在播放")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.regularMaterial, in: Capsule())
                        }

                        Spacer()

                        if let duration = video.duration, !duration.isEmpty {
                            Text(duration)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.65), in: Capsule())
                        }
                    }
                    .padding(5)
                }
            }
            .frame(width: 128)

            VStack(alignment: .leading, spacing: 6) {
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct RelatedVideoCard: View {
    let video: VideoRelatedRow
    let showPlaying: Bool
    var coverLayout: VideoCoverLayout = .landscape
    var expandsToFillWidth = false

    @ViewBuilder
    var body: some View {
        if expandsToFillWidth {
            cardContent
                .videoCardSurface()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            cardContent
                .frame(width: 172, alignment: .leading)
                .videoCardSurface()
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            VideoCardCover(
                urlString: video.coverUrl,
                resizeWidth: expandsToFillWidth ? 360 : 172,
                layout: coverLayout
            ) {
                if showPlaying && video.isPlaying {
                    VStack {
                        Spacer()
                        HStack {
                            Text("正在播放")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                            Spacer()
                        }
                        .padding(6)
                    }
                }
            }

            Text(video.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(height: 38, alignment: .topLeading)

            if coverLayout == .landscape {
                if !video.metadata.isEmpty {
                    Text(video.metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(height: 34, alignment: .topLeading)
                } else {
                    Color.clear.frame(height: 34)
                }
            }
        }
    }
}

extension VideoDetailScreenSnapshot {
    var coverURL: URL? {
        coverUrl.flatMap(URL.init(string:))
    }
}

extension VideoArtistRow {
    var avatarURL: URL? {
        avatarUrl.flatMap(URL.init(string:))
    }
}

extension VideoRelatedRow {
    var coverURL: URL? {
        coverUrl.flatMap(URL.init(string:))
    }
}

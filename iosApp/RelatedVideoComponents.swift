import SwiftUI
import Han1meShared

struct HorizontalVideoSection: View {
    let title: String
    let subtitle: String?
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let showPlaying: Bool
    let showsMetadataFooter: Bool

    @State private var selectedVideo: VideoRelatedRow?
    @State private var isShowingVideoList = false

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
                TapOnlyControl {
                    isShowingVideoList = true
                } label: {
                    Text("更多")
                        .font(.caption.weight(.semibold))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(videos) { video in
                        ManualNavigationCard {
                            selectedVideo = video
                        } label: {
                            RelatedVideoCard(
                                video: video,
                                showPlaying: showPlaying,
                                showsMetadataFooter: showsMetadataFooter,
                                width: 172
                            )
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isShowingVideoList) {
            RelatedVideoListView(
                title: title,
                videos: videos,
                videoFeature: videoFeature,
                commentFeature: commentFeature,
                showPlaying: showPlaying,
                showsMetadataFooter: showsMetadataFooter
            )
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedVideo != nil },
                set: { if !$0 { selectedVideo = nil } }
            )
        ) {
            if let selectedVideo {
                VideoDetailView(
                    videoCode: selectedVideo.videoCode,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }
        }
    }
}

struct RelatedVideoListView: View {
    let title: String
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let showPlaying: Bool
    let showsMetadataFooter: Bool

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(videos) { video in
                    NavigationLink {
                        VideoDetailView(
                            videoCode: video.videoCode,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature
                        )
                    } label: {
                        RelatedVideoCard(
                            video: video,
                            showPlaying: showPlaying,
                            showsMetadataFooter: showsMetadataFooter
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnAppear()
    }
}

struct RelatedVideoGrid: View {
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature

    @State private var selectedVideo: VideoRelatedRow?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("相关影片")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                ForEach(videos) { video in
                    ManualNavigationCard {
                        selectedVideo = video
                    } label: {
                        RelatedVideoCard(video: video, showPlaying: false)
                    }
                }
            }
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedVideo != nil },
                set: { if !$0 { selectedVideo = nil } }
            )
        ) {
            if let selectedVideo {
                VideoDetailView(
                    videoCode: selectedVideo.videoCode,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }
        }
    }
}

private struct ManualNavigationCard<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        label()
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

struct TabletRelatedSidebar: View {
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("相关影片")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

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
            .padding(.bottom, 24)
        }
    }
}

struct TabletRelatedVideoRow: View {
    let video: VideoRelatedRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CachedRemoteImage(urlString: video.coverUrl, resizeWidth: 128)
                .frame(width: 128, height: 72)
                .clipped()

                if let duration = video.duration, !duration.isEmpty {
                    Text(duration)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
    let showsMetadataFooter: Bool
    let width: CGFloat?

    init(
        video: VideoRelatedRow,
        showPlaying: Bool,
        showsMetadataFooter: Bool = true,
        width: CGFloat? = nil
    ) {
        self.video = video
        self.showPlaying = showPlaying
        self.showsMetadataFooter = showsMetadataFooter
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                CachedRemoteImage(urlString: video.coverUrl, resizeWidth: 172)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)

                LinearGradient(
                    colors: [
                        .clear,
                        Color(.secondarySystemBackground).opacity(0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 36)

                HStack(spacing: 5) {
                    if let views = video.views, !views.isEmpty {
                        Label(views, systemImage: "play.circle")
                            .labelStyle(.titleAndIcon)
                    }

                    Spacer(minLength: 8)

                    if let duration = video.duration, !duration.isEmpty {
                        Label(duration, systemImage: "clock")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.bottom, 5)
            }
            .overlay(alignment: .topLeading) {
                if showPlaying && video.isPlaying {
                    Text("正在播放")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: Capsule())
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Group {
                if #available(iOS 17.0, *) {
                    Text(video.title)
                        .lineLimit(2, reservesSpace: true)
                } else {
                    Text(video.title)
                        .lineLimit(2)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsMetadataFooter {
                HStack(spacing: 6) {
                    MarqueeText(text: video.artistLabel)
                    if let uploadTime = video.uploadTime, !uploadTime.isEmpty {
                        Text(uploadTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
            }
        }
        .frame(width: width, alignment: .leading)
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension VideoRelatedRow {
    var artistLabel: String {
        guard let artist, !artist.isEmpty else {
            return String(localized: "common.artist")
        }
        return artist
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

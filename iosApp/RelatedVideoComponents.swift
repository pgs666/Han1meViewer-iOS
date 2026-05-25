import SwiftUI
import Han1meShared

struct HorizontalVideoSection: View {
    let title: String
    let subtitle: String?
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
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
                NavigationLink {
                    RelatedVideoListView(
                        title: title,
                        videos: videos,
                        videoFeature: videoFeature,
                        commentFeature: commentFeature,
                        showPlaying: showPlaying
                    )
                } label: {
                    Text("更多")
                        .font(.caption.weight(.semibold))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(videos) { video in
                        NavigationLink {
                            VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
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

struct RelatedVideoListView: View {
    let title: String
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let showPlaying: Bool

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
                        RelatedVideoCard(video: video, showPlaying: showPlaying)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RelatedVideoGrid: View {
    let videos: [VideoRelatedRow]
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("相关影片")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                ForEach(videos) { video in
                    NavigationLink {
                        VideoDetailView(videoCode: video.videoCode, videoFeature: videoFeature, commentFeature: commentFeature)
                    } label: {
                        RelatedVideoCard(video: video, showPlaying: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                AsyncImage(url: video.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                }
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

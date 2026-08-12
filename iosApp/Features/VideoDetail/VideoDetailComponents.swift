import SwiftUI
import UIKit
import Han1meShared

struct AndroidStyleIntroduction: View {
    let snapshot: VideoDetailScreenSnapshot
    let videoFeature: VideoFeature
    let commentFeature: CommentFeature
    let isArtistActionRunning: Bool
    let onToggleArtistSubscription: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleWatchLater: () -> Void
    let onSetMyListItem: (VideoMyListRow, Bool) -> Void
    let onShowMessage: (String) -> Void
    let onOpenSeriesVideo: (String) -> Void
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
                TagFlow(tags: snapshot.tags, videoFeature: videoFeature, commentFeature: commentFeature)
            }

            if !snapshot.playlistVideos.isEmpty {
                HorizontalVideoSection(
                    title: "系列影片",
                    subtitle: snapshot.playlistName,
                    videos: snapshot.playlistVideos,
                    showPlaying: true,
                    onOpenVideo: onOpenSeriesVideo
                )
            }

            if showsRelated && !snapshot.relatedVideos.isEmpty {
                RelatedVideoGrid(
                    videos: snapshot.relatedVideos,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature,
                    coverLayout: snapshot.relatedVideosUsePortraitCovers ? .hanimePortrait : .landscape
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
            Button("取消订阅", role: .destructive, action: toggleAction)
            Button("不取消", role: .cancel) {}
        } message: {
            Text("确定要取消订阅吗？")
        }
    }

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
            CachedRemoteImage(urlString: artist.avatarUrl, resizeWidth: 52)
            .frame(width: 52, height: 52)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let genre = artist.genre, !genre.isEmpty {
                    Text(genre).font(.subheadline).foregroundStyle(.secondary)
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
                Text(snapshot.title).font(.headline).foregroundStyle(.secondary).textSelection(.enabled)
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
                Divider().frame(height: 16)
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
            Text(text).font(.body).foregroundStyle(.primary).lineLimit(expanded ? nil : 4).textSelection(.enabled)
            Button(expanded ? String(localized: "收起") : String(localized: "展开")) {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
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
    let onDownload: (VideoPlaybackSourceRow) -> Void
    @Environment(\.openURL) private var openURL
    @State private var isShowingMyList = false
    @State private var isShowingMoreActions = false
    @State private var isShowingShareSheet = false
    @State private var isShowingDownloadQuality = false

    private var videoURL: URL? { siteURL(path: "/watch") }
    private var downloadURL: URL? { siteURL(path: "/download") }
    private var downloadableSources: [VideoPlaybackSourceRow] {
        snapshot.playbackSources.filter { $0.label.uppercased() != "AUTO" && !$0.url.isEmpty }
    }

    private func siteURL(path: String) -> URL? {
        guard let url = AppDomain.appending(
            path.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            to: AppDomain.currentBaseURL
        ), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = [URLQueryItem(name: "v", value: snapshot.videoCode)]
        return components.url
    }

    var body: some View {
        HStack(spacing: 6) {
            LabelButton(title: snapshot.isFav ? "已收藏" : "收藏", systemImage: snapshot.isFav ? "heart.fill" : "heart", action: onToggleFavorite)
            LabelButton(title: snapshot.isWatchLater ? "已稍后" : "稍后观看", systemImage: "text.badge.plus", action: onToggleWatchLater)
            LabelButton(title: "更多", systemImage: "ellipsis.circle") { isShowingMoreActions = true }
            LabelButton(title: "分享", systemImage: "square.and.arrow.up") {
                if videoURL != nil { isShowingShareSheet = true }
            }
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
                    if let downloadURL { openURL(downloadURL) }
                } else {
                    isShowingDownloadQuality = true
                }
            }
            if snapshot.originalComic?.isEmpty == false {
                Button("原作漫画") {
                    if let originalComic = snapshot.originalComic, let url = URL(string: originalComic) { openURL(url) }
                }
            }
            Button("网页") { if let videoURL { openURL(videoURL) } }
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
            if let videoURL { ActivityView(activityItems: [videoURL]).presentationDragIndicator(.visible) }
        }
        .confirmationDialog("选择下载画质", isPresented: $isShowingDownloadQuality, titleVisibility: .visible) {
            ForEach(downloadableSources) { source in Button(source.label) { onDownload(source) } }
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LabelButton: View {
    let title: String
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) { LabelButtonContent(title: title, systemImage: systemImage) }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity)
    }
}

private struct LabelButtonContent: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.title3)
            Text(title).font(.caption).lineLimit(1)
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
            Text("标签").font(.headline)
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
                        Button(tag) {}.font(.caption).buttonStyle(.bordered).disabled(true)
                    }
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = arrange(in: maxWidth, subviews: subviews)
        return CGSize(width: maxWidth.isFinite ? maxWidth : result.usedWidth, height: result.totalHeight)
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
        return Arranged(frames: frames, totalHeight: y + currentRowHeight, usedWidth: maxRowEnd)
    }
}

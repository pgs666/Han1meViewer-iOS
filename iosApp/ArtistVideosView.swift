import SwiftUI
import Han1meShared

/// Generic grid-layout list of search results, used as the destination for
/// every "show more videos like X" entry point: artist tap, tag tap, home-
/// page banner / category 更多. Reuses `SearchViewModel` / `SearchFeature`
/// so the result list shares the same pagination / loading-more semantics
/// as the main search page, without ever switching the user to the search
/// tab itself.
///
/// Two modes:
/// - `.keyword(name)` — runs `/search?query=<name>`; used by the artist
///   card (artist name) and by the tag flow (tag name).
/// - `.homeSection(request)` — runs the canonical home-section filter
///   (`SearchFilterState.homeSection(...)`); used by the home banner /
///   category 更多 buttons.
struct ArtistVideosView: View {
    /// Title shown in the navigation bar.
    let title: String
    let mode: Mode
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    @StateObject private var viewModel: SearchViewModel
    @State private var didStartLoading = false

    enum Mode {
        case keyword(String)
        case homeSection(SearchLaunchRequest)
    }

    /// Convenience initialiser used by the artist card path. Same as the
    /// generic init below, with `mode = .keyword(artistName)`. Kept so the
    /// existing `ArtistVideosView(artistName:...)` call sites at video-
    /// detail and following-list don't have to change.
    init(artistName: String, searchFeature: SearchFeature, videoFeature: VideoFeature, commentFeature: CommentFeature) {
        self.init(
            title: artistName,
            mode: .keyword(artistName),
            searchFeature: searchFeature,
            videoFeature: videoFeature,
            commentFeature: commentFeature
        )
    }

    init(title: String, mode: Mode, searchFeature: SearchFeature, videoFeature: VideoFeature, commentFeature: CommentFeature) {
        self.title = title
        self.mode = mode
        self.videoFeature = videoFeature
        self.commentFeature = commentFeature
        _viewModel = StateObject(wrappedValue: SearchViewModel(searchFeature: searchFeature))
    }

    var body: some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .hidesTabBarOnAppear()
            .logScreen("VideoGrid \(title)")
            .onAppear {
                guard !didStartLoading else { return }
                didStartLoading = true
                load()
            }
    }

    private func load() {
        switch mode {
        case .keyword(let keyword):
            viewModel.search(keyword: keyword, recordHistory: false)
        case .homeSection(let request):
            viewModel.openHomeSection(request, catalog: SearchOptionCatalog.shared)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("加载失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    load()
                }
                .buttonStyle(.borderedProminent)
                CloudflareVerifyButton(errorMessage: message)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot), .loadingMore(let snapshot):
            grid(snapshot: snapshot)
        }
    }

    private func grid(snapshot: SearchScreenSnapshot) -> some View {
        ScrollView {
            if snapshot.results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("没有找到相关视频。")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 80)
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(snapshot.results) { video in
                        NavigationLink {
                            VideoDetailView(
                                videoCode: video.videoCode,
                                videoFeature: videoFeature,
                                commentFeature: commentFeature
                            )
                        } label: {
                            SearchVideoCard(video: video)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentItemID: video.id)
                        }
                    }
                }
                .padding(16)

                PaginationFooterView(
                    isLoadingMore: {
                        if case .loadingMore = viewModel.state { return true }
                        return false
                    }(),
                    hasNext: snapshot.hasNext,
                    loadMoreError: snapshot.loadMoreError,
                    isEmpty: snapshot.results.isEmpty,
                    onRetry: {
                        viewModel.loadMoreIfNeeded(currentItemID: snapshot.results.last?.id)
                    }
                )
                .padding(.bottom, 24)
            }
        }
        .refreshable {
            load()
        }
    }
}

/// Grid-style card for `SearchVideoRow`. Matches the home-page card
/// layout: duration + view count overlaid on the cover, title below,
/// then a footer row with artist (left, auto-scrolls when too long) +
/// upload time (right). Same shape is used by the related-videos grid
/// on the video detail page so all the "tap a tile to play" surfaces
/// read as one family.
struct SearchVideoCard: View {
    let video: SearchVideoRow

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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Reserve a fixed two-line slot for the title so cards with
            // a single-line title still occupy the same vertical space
            // as cards with a wrapped title — without this the grid
            // ended up with mismatched cell heights and looked uneven.
            // .lineLimit(_:reservesSpace:) is iOS 17+; on iOS 16 we
            // fall back to plain .lineLimit(2) (cells will be slightly
            // uneven there but the deployment target is mostly future
            // OS so this matters less).
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

            // Footer row: artist on the left (auto-scrolls if too long),
            // upload time on the right.
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
}

private extension SearchVideoRow {
    var artistLabel: String {
        guard let artist, !artist.isEmpty else {
            return String(localized: "common.artist")
        }
        return artist
    }
}

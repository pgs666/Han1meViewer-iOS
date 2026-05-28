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

/// Grid-style card for `SearchVideoRow`. Same vertical layout the related-
/// videos grid uses on the video detail page, so both screens read as
/// part of the same family of "tap a tile to play".
struct SearchVideoCard: View {
    let video: SearchVideoRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedRemoteImage(urlString: video.coverUrl, resizeWidth: 172)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
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
    }
}

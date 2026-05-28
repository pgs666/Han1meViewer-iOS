import SwiftUI
import Han1meShared

/// Pushed from `ArtistCard` in `VideoDetailView`. Reuses `SearchViewModel` /
/// `SearchFeature` to query Hanime's `/search?query=<artist-name>` endpoint
/// (which is exactly what the website's artist page does — there is no
/// dedicated artist-videos endpoint on the server side). Displays the result
/// list with the same row layout as the global search page.
struct ArtistVideosView: View {
    let artistName: String
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    @StateObject private var viewModel: SearchViewModel
    @State private var didStartLoading = false

    init(artistName: String, searchFeature: SearchFeature, videoFeature: VideoFeature, commentFeature: CommentFeature) {
        self.artistName = artistName
        self.videoFeature = videoFeature
        self.commentFeature = commentFeature
        _viewModel = StateObject(wrappedValue: SearchViewModel(searchFeature: searchFeature))
    }

    var body: some View {
        content
            .navigationTitle(artistName)
            .navigationBarTitleDisplayMode(.inline)
            .hidesTabBarOnAppear()
            .onAppear {
                guard !didStartLoading else { return }
                didStartLoading = true
                viewModel.search(keyword: artistName, recordHistory: false)
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
                    viewModel.search(keyword: artistName, recordHistory: false)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot), .loadingMore(let snapshot):
            resultList(snapshot: snapshot)
        }
    }

    private func resultList(snapshot: SearchScreenSnapshot) -> some View {
        List {
            if snapshot.results.isEmpty {
                Text("没有找到该作者的视频。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.results) { video in
                    NavigationLink {
                        VideoDetailView(
                            videoCode: video.videoCode,
                            videoFeature: videoFeature,
                            commentFeature: commentFeature
                        )
                    } label: {
                        SearchResultRow(video: video)
                    }
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentItemID: video.id)
                    }
                }
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
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.search(keyword: artistName, recordHistory: false)
        }
    }
}

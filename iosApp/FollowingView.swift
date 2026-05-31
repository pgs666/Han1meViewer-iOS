import SwiftUI
import Han1meShared

struct FollowingView: View {
    @StateObject private var viewModel: FollowingViewModel
    /// Default false → the subscribed-artists row is a horizontal scroll
    /// strip (compact). Tapping the section header's expand button flips
    /// it true and the row reflows into a full LazyVGrid that shows every
    /// artist at once. Animated via withAnimation so the transition is
    /// smooth instead of snapping.
    @State private var isArtistsExpanded = false
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature
    private let searchFeature: SearchFeature

    init(environment: SharedAppEnvironment) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        self.searchFeature = environment.searchFeature()
        _viewModel = StateObject(wrappedValue: FollowingViewModel(followingFeature: environment.followingFeature()))
    }

    var body: some View {
        CompatibleNavigationStack {
            content
                .navigationTitle("关注")
                .logScreen("Following")
                .refreshable {
                    await viewModel.refresh()
                }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .onDisappear {
            viewModel.cancelLoading()
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
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "heart.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("关注加载失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    viewModel.load()
                }
                .buttonStyle(.borderedProminent)
                CloudflareVerifyButton(errorMessage: message)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot), .loadingMore(let snapshot):
            List {
                if !snapshot.artists.isEmpty {
                    Section {
                        if isArtistsExpanded {
                            // Full grid: shows every subscribed artist
                            // at once. minimum: 84 leaves room for the
                            // 58pt avatar + 12pt of breathing room
                            // either side; the 1-line caption clamps
                            // to 72pt inside FollowingArtistCell so
                            // long names truncate uniformly.
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 84), spacing: 14)],
                                spacing: 14
                            ) {
                                ForEach(snapshot.artists) { artist in
                                    // value-based navigation: works around
                                    // the SwiftUI bug where multiple
                                    // NavigationLink { dest } inside a
                                    // LazyVGrid embedded in a List Section
                                    // all fire at once when any cell is
                                    // tapped (the user reported tapping one
                                    // artist pushed every artist).
                                    NavigationLink(value: artist) {
                                        FollowingArtistCell(artist: artist)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(snapshot.artists) { artist in
                                        NavigationLink(value: artist) {
                                            FollowingArtistCell(artist: artist)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("订阅作者")
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    isArtistsExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Text(isArtistsExpanded ? "收起" : "展开")
                                    Image(systemName: isArtistsExpanded ? "chevron.up" : "chevron.down")
                                        .imageScale(.small)
                                }
                                .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                            // Section header text is auto-uppercased on
                            // some locales; we don't want that bleeding
                            // into the button label, so opt out for the
                            // whole HStack.
                            .textCase(nil)
                        }
                    }
                }

                Section("关注更新") {
                    if snapshot.videos.isEmpty {
                        Text("暂无关注更新。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.videos) { video in
                            NavigationLink {
                                VideoDetailView(
                                    videoCode: video.videoCode,
                                    videoFeature: videoFeature,
                                    commentFeature: commentFeature
                                )
                            } label: {
                                FollowingVideoRowView(video: video)
                            }
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItemID: video.id)
                            }
                        }
                        followingFooter(snapshot: snapshot)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: FollowingArtistRow.self) { artist in
                ArtistVideosView(
                    artistName: artist.name,
                    searchFeature: searchFeature,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            }
        }
    }

    private var isLoading: Bool {
        viewModel.state.isLoading
    }

    @ViewBuilder
    private func followingFooter(snapshot: FollowingScreenSnapshot) -> some View {
        PaginationFooterView(
            isLoadingMore: {
                if case .loadingMore = viewModel.state { return true }
                return false
            }(),
            hasNext: snapshot.hasNext,
            loadMoreError: snapshot.loadMoreError,
            isEmpty: snapshot.videos.isEmpty,
            onRetry: {
                viewModel.loadMoreIfNeeded(currentItemID: snapshot.videos.last?.id)
            }
        )
    }
}

private struct FollowingArtistCell: View {
    let artist: FollowingArtistRow

    var body: some View {
        VStack(spacing: 8) {
            CachedRemoteImage(urlString: artist.avatarUrl, resizeWidth: 58)
                .frame(width: 58, height: 58)
                .clipShape(Circle())
            Text(artist.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 72)
        }
    }
}

private struct FollowingVideoRowView: View {
    let video: FollowingVideoRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: video.coverUrl, resizeWidth: 96)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .lineLimit(2)
                if !video.metadata.isEmpty {
                    Text(video.metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

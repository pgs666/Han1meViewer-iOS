import SwiftUI
import Han1meShared

struct FollowingView: View {
    @StateObject private var viewModel: FollowingViewModel
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature

    init(environment: SharedAppEnvironment) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        _viewModel = StateObject(wrappedValue: FollowingViewModel(followingFeature: environment.followingFeature()))
    }

    var body: some View {
        CompatibleNavigationStack {
            content
                .navigationTitle("关注")
                .refreshable {
                    viewModel.load()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewModel.load()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white)
                        }
                        .disabled(isLoading)
                    }
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot), .loadingMore(let snapshot):
            List {
                if !snapshot.artists.isEmpty {
                    Section("订阅作者") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(snapshot.artists) { artist in
                                    FollowingArtistCell(artist: artist)
                                }
                            }
                            .padding(.vertical, 4)
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

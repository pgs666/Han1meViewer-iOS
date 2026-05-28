import SwiftUI
import Han1meShared

struct UserPlaylistView: View {
    @StateObject private var viewModel: UserPlaylistViewModel
    private let environment: SharedAppEnvironment

    init(feature: UserPlaylistFeature, environment: SharedAppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: UserPlaylistViewModel(feature: feature))
    }

    var body: some View {
        content
            .navigationTitle("播放清单")
            .hidesTabBarOnAppear()
            .refreshable {
                await viewModel.refresh()
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
                Image(systemName: "list.bullet.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("播放清单加载失败")
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
            if snapshot.playlists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("暂无播放清单")
                        .font(.headline)
                    Text("网站里的播放清单会显示在这里。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(snapshot.playlists) { playlist in
                            NavigationLink {
                                UserVideoListView(
                                    title: playlist.title,
                                    emptyMessage: "暂无清单视频",
                                    feature: environment.playlistVideoListFeature(listCode: playlist.listCode),
                                    environment: environment
                                )
                            } label: {
                                UserPlaylistRowView(playlist: playlist)
                            }
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItemID: playlist.id)
                            }
                        }
                        footer(snapshot: snapshot)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var isLoading: Bool {
        viewModel.state.isLoading
    }

    @ViewBuilder
    private func footer(snapshot: UserPlaylistScreenSnapshot) -> some View {
        PaginationFooterView(
            isLoadingMore: {
                if case .loadingMore = viewModel.state { return true }
                return false
            }(),
            hasNext: snapshot.hasNext,
            loadMoreError: snapshot.loadMoreError,
            isEmpty: snapshot.playlists.isEmpty,
            onRetry: {
                viewModel.loadMoreIfNeeded(currentItemID: snapshot.playlists.last?.id)
            }
        )
    }
}

private struct UserPlaylistRowView: View {
    let playlist: UserPlaylistRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: playlist.coverUrl, resizeWidth: 96)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .lineLimit(2)
                Text(String(format: String(localized: "playlist.video_count"), playlist.total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

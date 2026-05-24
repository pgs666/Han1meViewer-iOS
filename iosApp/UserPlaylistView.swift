import SwiftUI
import Han1meShared

struct UserPlaylistView: View {
    @StateObject private var viewModel: UserPlaylistViewModel

    init(feature: UserPlaylistFeature) {
        _viewModel = StateObject(wrappedValue: UserPlaylistViewModel(feature: feature))
    }

    var body: some View {
        content
            .navigationTitle("播放清单")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.load()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if case .idle = viewModel.state {
                    viewModel.load()
                }
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
                            UserPlaylistRowView(playlist: playlist)
                                .onAppear {
                                    viewModel.loadMoreIfNeeded(currentPlaylistID: playlist.id)
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
        switch viewModel.state {
        case .loading, .loadingMore:
            return true
        case .idle, .loaded, .failed:
            return false
        }
    }

    @ViewBuilder
    private func footer(snapshot: UserPlaylistScreenSnapshot) -> some View {
        switch viewModel.state {
        case .loadingMore:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 10)
        default:
            if let message = snapshot.loadMoreError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("加载更多失败")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("重试") {
                        viewModel.loadMoreIfNeeded(currentPlaylistID: snapshot.playlists.last?.id)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 8)
            } else if snapshot.hasNext {
                HStack {
                    Spacer()
                    ProgressView()
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentPlaylistID: snapshot.playlists.last?.id)
                        }
                    Spacer()
                }
                .padding(.vertical, 10)
            } else {
                Text("已全部加载")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }
}

private struct UserPlaylistRowView: View {
    let playlist: UserPlaylistRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: playlist.coverUrl)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .lineLimit(2)
                Text("\(playlist.total) 个视频")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

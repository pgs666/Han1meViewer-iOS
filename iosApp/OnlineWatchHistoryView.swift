import SwiftUI
import Han1meShared

struct OnlineWatchHistoryView: View {
    @StateObject private var viewModel: OnlineWatchHistoryViewModel
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature

    init(environment: SharedAppEnvironment) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        _viewModel = StateObject(
            wrappedValue: OnlineWatchHistoryViewModel(feature: environment.onlineWatchHistoryFeature())
        )
    }

    var body: some View {
        content
            .navigationTitle("在线历史")
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
            .alert("操作失败", isPresented: actionErrorBinding) {
                Button("好", role: .cancel) {
                    viewModel.actionErrorMessage = nil
                }
            } message: {
                Text(viewModel.actionErrorMessage ?? "")
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
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("在线历史加载失败")
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
                Section {
                    Picker("排序", selection: sortBinding) {
                        ForEach(OnlineWatchHistoryViewModel.SortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if snapshot.videos.isEmpty {
                        Text("暂无在线历史。")
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
                                OnlineWatchHistoryRowView(video: video)
                            }
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItemID: video.id)
                            }
                        }
                        .onDelete(perform: viewModel.delete)
                        footer(snapshot: snapshot)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var sortBinding: Binding<OnlineWatchHistoryViewModel.SortMode> {
        Binding(
            get: { viewModel.sortMode },
            set: { viewModel.changeSortMode($0) }
        )
    }

    private var isLoading: Bool {
        viewModel.state.isLoading
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.actionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.actionErrorMessage = nil
                }
            }
        )
    }

    @ViewBuilder
    private func footer(snapshot: OnlineWatchHistoryScreenSnapshot) -> some View {
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

private struct OnlineWatchHistoryRowView: View {
    let video: OnlineWatchHistoryRow

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

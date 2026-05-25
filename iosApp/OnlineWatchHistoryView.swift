import SwiftUI
import Han1meShared

struct OnlineWatchHistoryView: View {
    @StateObject private var viewModel: OnlineWatchHistoryViewModel
    private let environment: SharedAppEnvironment

    init(environment: SharedAppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(
            wrappedValue: OnlineWatchHistoryViewModel(feature: environment.onlineWatchHistoryFeature())
        )
    }

    var body: some View {
        content
            .navigationTitle("在线历史")
            .refreshable {
                viewModel.load()
            }
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
                                    videoFeature: environment.videoFeature(),
                                    commentFeature: environment.commentFeature()
                                )
                            } label: {
                                OnlineWatchHistoryRowView(video: video)
                            }
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentVideoID: video.id)
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
        switch viewModel.state {
        case .loading, .loadingMore:
            return true
        case .idle, .loaded, .failed:
            return false
        }
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
                        viewModel.loadMoreIfNeeded(currentVideoID: snapshot.videos.last?.id)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 8)
            } else if snapshot.hasNext {
                HStack {
                    Spacer()
                    ProgressView()
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentVideoID: snapshot.videos.last?.id)
                        }
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if !snapshot.videos.isEmpty {
                Text("已全部加载")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }
}

private struct OnlineWatchHistoryRowView: View {
    let video: OnlineWatchHistoryRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: video.coverUrl)
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

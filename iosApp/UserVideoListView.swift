import SwiftUI
import Han1meShared

struct UserVideoListView: View {
    @StateObject private var viewModel: UserVideoListViewModel
    private let title: String
    private let emptyMessage: String
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature

    init(
        title: String,
        emptyMessage: String,
        feature: UserVideoListFeature,
        environment: SharedAppEnvironment
    ) {
        self.title = title
        self.emptyMessage = emptyMessage
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        _viewModel = StateObject(wrappedValue: UserVideoListViewModel(feature: feature))
    }

    init(
        title: String,
        emptyMessage: String,
        feature: PlaylistVideoListFeature,
        environment: SharedAppEnvironment
    ) {
        self.title = title
        self.emptyMessage = emptyMessage
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        _viewModel = StateObject(wrappedValue: UserVideoListViewModel(feature: feature))
    }

    var body: some View {
        content
            .navigationTitle(title)
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
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(String(format: String(localized: "user_list.load_failed"), title))
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
            if snapshot.videos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(emptyMessage)
                        .font(.headline)
                    Text("登录后的网站列表会显示在这里。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if let listDescription = snapshot.listDescription, !listDescription.isEmpty {
                        Section {
                            Text(listDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        if viewModel.canRemoveItems {
                            removableVideoRows(snapshot: snapshot)
                        } else {
                            videoRows(snapshot: snapshot)
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

    private func videoRows(snapshot: UserVideoListScreenSnapshot) -> some View {
        ForEach(snapshot.videos) { video in
            NavigationLink {
                VideoDetailView(
                    videoCode: video.videoCode,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            } label: {
                UserVideoListRowView(video: video)
            }
            .onAppear {
                viewModel.loadMoreIfNeeded(currentVideoID: video.id)
            }
        }
    }

    private func removableVideoRows(snapshot: UserVideoListScreenSnapshot) -> some View {
        ForEach(snapshot.videos) { video in
            NavigationLink {
                VideoDetailView(
                    videoCode: video.videoCode,
                    videoFeature: videoFeature,
                    commentFeature: commentFeature
                )
            } label: {
                UserVideoListRowView(video: video)
            }
            .onAppear {
                viewModel.loadMoreIfNeeded(currentVideoID: video.id)
            }
        }
        .onDelete(perform: viewModel.delete)
    }

    @ViewBuilder
    private func footer(snapshot: UserVideoListScreenSnapshot) -> some View {
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

private struct UserVideoListRowView: View {
    let video: UserVideoListRow

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

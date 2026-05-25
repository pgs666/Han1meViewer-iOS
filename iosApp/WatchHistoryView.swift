import SwiftUI
import Han1meShared

struct WatchHistoryView: View {
    @StateObject private var viewModel: WatchHistoryViewModel
    private let environment: SharedAppEnvironment

    init(environment: SharedAppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: WatchHistoryViewModel(watchHistoryFeature: environment.watchHistoryFeature()))
    }

    var body: some View {
        content
            .navigationTitle("观看历史")
            .onAppear {
                viewModel.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ProgressView()
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("历史记录加载失败")
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
        case .loaded(let snapshot):
            if snapshot.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("暂无观看历史")
                        .font(.headline)
                    Text("打开视频详情后会自动记录到这里。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(snapshot.items) { item in
                        NavigationLink {
                            VideoDetailView(
                                videoCode: item.videoCode,
                                videoFeature: environment.videoFeature(),
                                commentFeature: environment.commentFeature()
                            )
                        } label: {
                            WatchHistoryRowView(item: item)
                        }
                    }
                    .onDelete { offsets in
                        offsets
                            .map { snapshot.items[$0].videoCode }
                            .forEach { viewModel.delete(videoCode: $0) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

private struct WatchHistoryRowView: View {
    let item: WatchHistoryRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: item.coverUrl)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .lineLimit(2)
                Text(item.watchedAtText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

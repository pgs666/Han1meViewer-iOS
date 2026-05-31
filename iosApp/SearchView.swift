import SwiftUI
import UIKit
import Han1meShared

struct SearchView: View {
    @State private var keyword = ""
    @State private var isShowingFilters = false
    @State private var catalog = SearchOptionCatalog.empty
    @StateObject private var viewModel: SearchViewModel
    @Binding private var launchRequest: SearchLaunchRequest?
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature

    init(environment: SharedAppEnvironment, launchRequest: Binding<SearchLaunchRequest?> = .constant(nil)) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        _launchRequest = launchRequest
        _viewModel = StateObject(wrappedValue: SearchViewModel(searchFeature: environment.searchFeature()))
    }

    var body: some View {
        CompatibleNavigationStack {
            content
            .navigationTitle("搜索")
            .logScreen("Search")
            .searchable(
                text: $keyword,
                placement: .automatic,
                prompt: "搜索影片、标签或作者"
            )
            .onSubmit(of: .search) {
                let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty || viewModel.filters.activeCount > 0 else { return }
                viewModel.search(keyword: keyword)
            }
            .background(SearchTextFieldReturnKeyEnabler())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(viewModel.filters.activeCount > 0 ? Color.accentColor : Color.primary)
                    }
                    .tint(viewModel.filters.activeCount > 0 ? Color.accentColor : Color.primary)
                }
            }
            .onAppear {
                viewModel.loadHistoryIfNeeded()
                consumeLaunchRequestIfNeeded()
            }
            .task {
                await loadCatalogIfNeeded()
                consumeLaunchRequestIfNeeded()
            }
            .onValueChange(of: launchRequest?.id) { _ in
                consumeLaunchRequestIfNeeded()
            }
            .onValueChange(of: catalog.isLoaded) { _ in
                consumeLaunchRequestIfNeeded()
            }
            .sheet(isPresented: $isShowingFilters) {
                SearchFilterSheet(
                    catalog: catalog,
                    initialFilters: viewModel.filters,
                    onApply: { filters in
                        viewModel.search(keyword: keyword, filters: filters)
                    },
                    onReset: {
                        viewModel.resetFilters()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleContent
        case .loading:
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("搜索失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    viewModel.search(keyword: keyword)
                }
                .buttonStyle(.borderedProminent)
                CloudflareVerifyButton(errorMessage: message)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot), .loadingMore(let snapshot):
            resultList(snapshot: snapshot)
        }
    }

    private var idleContent: some View {
        Group {
            if viewModel.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("暂无搜索历史")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("搜索历史")
                                .font(.title2.weight(.bold))
                            Spacer()
                            Button("清空") {
                                viewModel.clearHistory()
                            }
                            .font(.caption)
                        }

                        VStack(spacing: 0) {
                            ForEach(viewModel.history) { item in
                                Button {
                                    keyword = item.keyword
                                    viewModel.restoreFromHistory(item)
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)

                                            if item.hasKeyword && item.hasFilterSummary {
                                                Text(item.filterSummary)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 13)
                                }
                                if item.id != viewModel.history.last?.id {
                                    Divider()
                                        .padding(.leading, 28)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .background(Color(.systemBackground))
            }
        }
    }

    private func consumeLaunchRequestIfNeeded() {
        guard let request = launchRequest else {
            return
        }
        guard catalog.isLoaded else {
            return
        }
        keyword = ""
        if let requestKeyword = request.keyword {
            keyword = requestKeyword
            viewModel.search(keyword: requestKeyword, recordHistory: false)
        } else {
            viewModel.openHomeSection(request, catalog: catalog)
        }
        launchRequest = nil
    }

    private func loadCatalogIfNeeded() async {
        guard !catalog.isLoaded else {
            return
        }
        catalog = await Task.detached(priority: .utility) {
            SearchOptionCatalog()
        }.value
    }

    private func resultList(snapshot: SearchScreenSnapshot) -> some View {
        List {
            Section {
                if snapshot.results.isEmpty {
                    Text("没有找到结果。")
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
                    searchFooter(snapshot: snapshot)
                }
            } header: {
                HStack {
                    Text("结果")
                    Spacer()
                    Button {
                        keyword = ""
                        viewModel.showHistory()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回搜索历史")
                    .foregroundStyle(.secondary)
                }
            }
        }
        .refreshable {
            viewModel.search(keyword: keyword)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func searchFooter(snapshot: SearchScreenSnapshot) -> some View {
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

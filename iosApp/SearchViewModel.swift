import Foundation
import Han1meShared

@MainActor
final class SearchViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(SearchScreenSnapshot)
        case loadingMore(SearchScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var history: [SearchHistoryRow] = []
    @Published var filters = SearchFilterState()

    private let searchFeature: SearchFeature
    private var currentKeyword = ""
    private var currentFilters = SearchFilterState()
    private var currentPage: Int32 = 0
    private var hasNextPage = false
    private var didLoadHistory = false
    private var searchTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(searchFeature: SearchFeature) {
        self.searchFeature = searchFeature
    }

    deinit {
        searchTask?.cancel()
        loadMoreTask?.cancel()
    }

    func loadHistoryIfNeeded() {
        guard !didLoadHistory else {
            return
        }
        loadHistory()
    }

    private func loadHistory() {
        let snapshot = searchFeature.recentHistory(limit: 12)
        let count = Int(snapshot.itemCount())
        history = (0..<count).compactMap { index in
            guard let item = snapshot.itemAt(index: Int32(index)) else {
                return nil
            }
            return SearchHistoryRow(
                keyword: item.keyword,
                filterSummary: item.filterSummary
            )
        }
        didLoadHistory = true
    }

    func clearHistory() {
        _ = searchFeature.clearHistory()
        history = []
        didLoadHistory = true
    }

    func showHistory() {
        loadHistory()
        currentKeyword = ""
        currentPage = 0
        hasNextPage = false
        state = .idle
    }

    func search(keyword: String, filters: SearchFilterState? = nil, recordHistory: Bool = true) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextFilters = filters ?? self.filters
        searchTask?.cancel()
        loadMoreTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration

        currentKeyword = trimmedKeyword
        currentFilters = nextFilters
        self.filters = nextFilters
        currentPage = 0
        hasNextPage = false
        state = .loading
        searchTask = Task { [weak self] in
            await self?.loadSearch(
                keyword: trimmedKeyword,
                filters: nextFilters,
                page: 1,
                appendingTo: nil,
                recordHistory: recordHistory,
                generation: generation
            )
        }
    }

    func openHomeSection(_ request: SearchLaunchRequest, catalog: SearchOptionCatalog) {
        let filters = SearchFilterState.homeSection(key: request.sectionKey, catalog: catalog)
        search(keyword: "", filters: filters, recordHistory: false)
    }

    func resetFilters() {
        filters.reset()
    }

    func loadMoreIfNeeded(currentItemID: String?) {
        guard hasNextPage, !isLoading else {
            return
        }
        guard case .loaded(let snapshot) = state else {
            return
        }
        guard snapshot.results.last?.id == currentItemID else {
            return
        }

        let nextPage = currentPage + 1
        let generation = requestGeneration
        let keyword = currentKeyword
        let filters = currentFilters
        state = .loadingMore(snapshot)
        loadMoreTask = Task { [weak self] in
            await self?.loadSearch(
                keyword: keyword,
                filters: filters,
                page: nextPage,
                appendingTo: snapshot,
                recordHistory: false,
                generation: generation
            )
        }
    }

    private var isLoading: Bool {
        switch state {
        case .loading, .loadingMore:
            return true
        case .idle, .loaded, .failed:
            return false
        }
    }

    private func loadSearch(
        keyword: String,
        filters: SearchFilterState,
        page: Int32,
        appendingTo existingSnapshot: SearchScreenSnapshot?,
        recordHistory: Bool,
        generation: Int
    ) async {
        do {
            let snapshot = try await searchFeature.searchAdvanced(
                keyword: keyword,
                genre: filters.genre?.searchKey,
                sort: filters.sort?.searchKey,
                broad: filters.broad,
                releaseDate: filters.releaseDate?.searchKey,
                duration: filters.duration?.searchKey,
                tags: filters.selectedTagKeys.joined(separator: "\n"),
                brands: filters.selectedBrandKeys.joined(separator: "\n"),
                filterSummary: filters.summaryItems.joined(separator: " · "),
                page: page,
                recordHistory: recordHistory
            )
            guard !Task.isCancelled, generation == requestGeneration else { return }
            let screenSnapshot = SearchScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            currentPage = screenSnapshot.page
            hasNextPage = screenSnapshot.hasNext
            if recordHistory && page == 1 {
                loadHistory()
            }
            state = .loaded(screenSnapshot)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == requestGeneration else { return }
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
            if let existingSnapshot {
                state = .loaded(existingSnapshot.withLoadMoreError(ErrorMessage.userFriendly(error)))
            } else {
                state = .failed(ErrorMessage.userFriendly(error))
            }
        }
    }
}

struct SearchHistoryRow: Identifiable, Hashable {
    let keyword: String
    let filterSummary: String

    var id: String {
        "\(keyword)\n\(filterSummary)"
    }

    var hasKeyword: Bool {
        !keyword.isEmpty
    }

    var hasFilterSummary: Bool {
        !filterSummary.isEmpty
    }

    var title: String {
        hasKeyword ? keyword : (hasFilterSummary ? filterSummary : "空关键词")
    }
}

struct SearchScreenSnapshot {
    let results: [SearchVideoRow]
    let page: Int32
    let hasNext: Bool
    let loadMoreError: String?

    init(_ snapshot: SearchSnapshot, appendingTo existingSnapshot: SearchScreenSnapshot? = nil) {
        let count = Int(snapshot.itemCount())
        let newResults: [SearchVideoRow] = (0..<count).compactMap { index in
            guard let item = snapshot.itemAt(index: Int32(index)) else {
                return nil
            }
            return SearchVideoRow(
                videoCode: item.videoCode,
                title: item.title,
                coverUrl: item.coverUrl,
                duration: item.duration,
                views: item.views,
                uploadTime: item.uploadTime,
                artist: item.artist
            )
        }
        results = SearchScreenSnapshot.merging(existingSnapshot?.results ?? [], with: newResults)
        page = snapshot.page
        hasNext = snapshot.hasNext
        loadMoreError = nil
    }

    private init(results: [SearchVideoRow], page: Int32, hasNext: Bool, loadMoreError: String?) {
        self.results = results
        self.page = page
        self.hasNext = hasNext
        self.loadMoreError = loadMoreError
    }

    func withLoadMoreError(_ message: String) -> SearchScreenSnapshot {
        SearchScreenSnapshot(
            results: results,
            page: page,
            hasNext: hasNext,
            loadMoreError: message
        )
    }

    private static func merging(_ existing: [SearchVideoRow], with newResults: [SearchVideoRow]) -> [SearchVideoRow] {
        var seenIDs = Set(existing.map(\.id))
        var merged = existing
        for result in newResults where seenIDs.insert(result.id).inserted {
            merged.append(result)
        }
        return merged
    }
}

struct SearchVideoRow: Identifiable {
    let videoCode: String
    let title: String
    let coverUrl: String?
    let duration: String?
    let views: String?
    let uploadTime: String?
    let artist: String?

    var id: String { videoCode }

    var metadata: String {
        [artist, uploadTime, duration, views]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }
}

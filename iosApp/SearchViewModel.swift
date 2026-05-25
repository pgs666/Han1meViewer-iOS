import Foundation
import Han1meShared

@MainActor
final class SearchViewModel: PaginatedViewModel<SearchScreenSnapshot> {
    @Published private(set) var history: [SearchHistoryRow] = []
    @Published var filters = SearchFilterState()

    private let searchFeature: SearchFeature
    private var currentKeyword = ""
    private var currentFilters = SearchFilterState()
    private var didLoadHistory = false

    init(searchFeature: SearchFeature) {
        self.searchFeature = searchFeature
    }

    override func load() {
        search(keyword: currentKeyword, filters: currentFilters, recordHistory: false)
    }

    func loadHistoryIfNeeded() {
        guard !didLoadHistory else { return }
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
        filters.reset()
        state = .idle
    }

    func search(keyword: String, filters: SearchFilterState? = nil, recordHistory: Bool = true) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextFilters = filters ?? self.filters
        currentKeyword = trimmedKeyword
        currentFilters = nextFilters
        self.filters = nextFilters
        super.load()
    }

    func openHomeSection(_ request: SearchLaunchRequest, catalog: SearchOptionCatalog) {
        let filters = SearchFilterState.homeSection(key: request.sectionKey, catalog: catalog)
        search(keyword: "", filters: filters, recordHistory: false)
    }

    func resetFilters() {
        filters.reset()
    }

    override func executeLoad(page: Int32, appendingTo existingSnapshot: SearchScreenSnapshot?, generation: Int) async {
        do {
            let snapshot = try await searchFeature.searchAdvanced(
                keyword: currentKeyword,
                genre: currentFilters.genre?.searchKey,
                sort: currentFilters.sort?.searchKey,
                broad: currentFilters.broad,
                releaseDate: currentFilters.releaseDate?.searchKey,
                duration: currentFilters.duration?.searchKey,
                tags: currentFilters.selectedTagKeys.joined(separator: "\n"),
                brands: currentFilters.selectedBrandKeys.joined(separator: "\n"),
                filterSummary: currentFilters.summaryItems.joined(separator: " · "),
                page: page,
                recordHistory: page == 1
            )
            guard !Task.isCancelled, generation == currentGeneration else { return }
            let screenSnapshot = SearchScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            if page == 1 {
                loadHistory()
            }
            applyLoadResult(screenSnapshot)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == currentGeneration else { return }
            applyLoadError(error, appendingTo: existingSnapshot)
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

struct SearchScreenSnapshot: PaginatedSnapshot {
    let results: [SearchVideoRow]
    let page: Int32
    let hasNext: Bool
    let loadMoreError: String?

    var lastItemID: String? { results.last?.id }

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
        results = mergeByIdentifiable(existingSnapshot?.results ?? [], with: newResults)
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

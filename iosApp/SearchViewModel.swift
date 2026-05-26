import Foundation
import Han1meShared

@MainActor
final class SearchViewModel: PaginatedViewModel<SearchScreenSnapshot> {
    @Published private(set) var history: [SearchHistoryRow] = []
    @Published var filters = SearchFilterState()

    private let searchFeature: SearchFeature
    private var currentKeyword = ""
    private var currentFilters = SearchFilterState()
    private var currentRecordHistory = false
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
                filterSummary: item.filterSummary,
                filterData: item.filterData
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
        currentFilters = SearchFilterState()
        currentRecordHistory = false
        filters.reset()
        resetPaginationToIdle()
    }

    func restoreFromHistory(_ item: SearchHistoryRow) {
        // Restore filters from stored JSON
        if !item.filterData.isEmpty,
           let data = item.filterData.data(using: .utf8),
           let restored = try? JSONDecoder().decode(SearchFilterCodable.self, from: data) {
            filters = restored.toFilterState()
        }
        search(keyword: item.keyword, filters: filters)
    }

    func search(keyword: String, filters: SearchFilterState? = nil, recordHistory: Bool = true) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextFilters = filters ?? self.filters
        currentKeyword = trimmedKeyword
        currentFilters = nextFilters
        currentRecordHistory = recordHistory
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
            let filterDataJSON = Self.encodeFilterData(currentFilters)
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
                filterData: filterDataJSON,
                page: page,
                recordHistory: currentRecordHistory && page == 1
            )
            guard !Task.isCancelled, generation == currentGeneration else { return }
            let screenSnapshot = SearchScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            if currentRecordHistory && page == 1 {
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
    private static func encodeFilterData(_ filters: SearchFilterState) -> String {
        let codable = SearchFilterCodable.from(filters)
        guard let data = try? JSONEncoder().encode(codable),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }
}

struct SearchHistoryRow: Identifiable, Hashable {
    let keyword: String
    let filterSummary: String
    let filterData: String

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

struct SearchFilterCodable: Codable {
    let genre: String?
    let sort: String?
    let duration: String?
    let releaseDate: String?
    let broad: Bool
    let tags: [String]
    let brands: [String]

    static func from(_ state: SearchFilterState) -> SearchFilterCodable {
        SearchFilterCodable(
            genre: state.genre?.searchKey,
            sort: state.sort?.searchKey,
            duration: state.duration?.searchKey,
            releaseDate: state.releaseDate?.searchKey,
            broad: state.broad,
            tags: state.selectedTagKeys,
            brands: state.selectedBrandKeys
        )
    }

    func toFilterState() -> SearchFilterState {
        var state = SearchFilterState()
        // We can only restore the searchKeys; displayName will be resolved from catalog
        if let genre = genre { state.genre = SearchFilterOption(lang: nil, name: genre, searchKey: genre) }
        if let sort = sort { state.sort = SearchFilterOption(lang: nil, name: sort, searchKey: sort) }
        if let duration = duration { state.duration = SearchFilterOption(lang: nil, name: duration, searchKey: duration) }
        if let releaseDate = releaseDate { state.releaseDate = SearchFilterOption(lang: nil, name: releaseDate, searchKey: releaseDate) }
        state.broad = broad
        state.tags = Set(tags.map { SearchFilterOption(lang: nil, name: $0, searchKey: $0) })
        state.brands = Set(brands.map { SearchFilterOption(lang: nil, name: $0, searchKey: $0) })
        return state
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

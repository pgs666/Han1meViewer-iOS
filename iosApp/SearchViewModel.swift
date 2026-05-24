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

    private let searchFeature: SearchFeature
    private var currentKeyword = ""
    private var currentPage: Int32 = 0
    private var hasNextPage = false

    init(searchFeature: SearchFeature) {
        self.searchFeature = searchFeature
    }

    func search(keyword: String) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            state = .idle
            currentKeyword = ""
            currentPage = 0
            hasNextPage = false
            return
        }
        guard !isLoading else {
            return
        }

        currentKeyword = trimmedKeyword
        currentPage = 0
        hasNextPage = false
        state = .loading
        Task {
            await loadSearch(keyword: trimmedKeyword, page: 1, appendingTo: nil)
        }
    }

    func loadMoreIfNeeded(currentItemID: String?) {
        guard hasNextPage, !currentKeyword.isEmpty, !isLoading else {
            return
        }
        guard case .loaded(let snapshot) = state else {
            return
        }
        guard snapshot.results.last?.id == currentItemID else {
            return
        }

        let nextPage = currentPage + 1
        state = .loadingMore(snapshot)
        Task {
            await loadSearch(keyword: currentKeyword, page: nextPage, appendingTo: snapshot)
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

    private func loadSearch(keyword: String, page: Int32, appendingTo existingSnapshot: SearchScreenSnapshot?) async {
        do {
            let snapshot = try await searchFeature.search(keyword: keyword, page: page)
            let screenSnapshot = SearchScreenSnapshot(snapshot, appendingTo: existingSnapshot)
            currentPage = screenSnapshot.page
            hasNextPage = screenSnapshot.hasNext
            state = .loaded(screenSnapshot)
        } catch {
            if let existingSnapshot {
                state = .loaded(existingSnapshot.withLoadMoreError(ErrorMessage.userFriendly(error)))
            } else {
                state = .failed(ErrorMessage.userFriendly(error))
            }
        }
    }
}

struct SearchScreenSnapshot {
    let results: [SearchVideoRow]
    let page: Int32
    let hasNext: Bool
    let loadMoreError: String?

    init(_ snapshot: SearchSnapshot, appendingTo existingSnapshot: SearchScreenSnapshot? = nil) {
        let count = Int(snapshot.itemCount())
        let newResults = (0..<count).compactMap { index in
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

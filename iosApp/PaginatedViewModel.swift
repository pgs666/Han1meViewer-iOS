import SwiftUI

protocol PaginatedSnapshot {
    var page: Int32 { get }
    var hasNext: Bool { get }
    var loadMoreError: String? { get }
    var lastItemID: String? { get }
    func withLoadMoreError(_ message: String) -> Self
}

@MainActor
class PaginatedViewModel<S: PaginatedSnapshot>: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(S)
        case loadingMore(S)
        case failed(String)
    }

    @Published var state: State = .idle

    private var currentPage: Int32 = 0
    private var hasNextPage = false
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var requestGeneration = 0

    deinit {
        loadTask?.cancel()
        loadMoreTask?.cancel()
    }

    func load() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        currentPage = 0
        hasNextPage = false
        state = .loading
        loadTask = Task { [weak self] in
            await self?.executeLoad(page: 1, appendingTo: nil, generation: generation)
        }
    }

    func refresh() async {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        currentPage = 0
        hasNextPage = false
        let existingSnapshot: S? = if case .loaded(let s) = state { s } else { nil }
        await executeLoad(page: 1, appendingTo: existingSnapshot, generation: generation)
    }

    func loadIfNeeded() {
        if case .idle = state {
            load()
        }
    }

    func loadMoreIfNeeded(currentItemID: String?) {
        guard hasNextPage, !state.isLoading else { return }
        guard case .loaded(let snapshot) = state else { return }
        guard snapshot.lastItemID == currentItemID else { return }

        let nextPage = currentPage + 1
        let generation = requestGeneration
        state = .loadingMore(snapshot)
        loadMoreTask = Task { [weak self] in
            await self?.executeLoad(page: nextPage, appendingTo: snapshot, generation: generation)
        }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        switch state {
        case .loading:
            state = .idle
        case .loadingMore(let snapshot):
            state = .loaded(snapshot)
        case .idle, .loaded, .failed:
            break
        }
    }

    func resetPaginationToIdle() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        requestGeneration += 1
        currentPage = 0
        hasNextPage = false
        state = .idle
    }

    var currentGeneration: Int { requestGeneration }

    func applyLoadResult(_ snapshot: S) {
        currentPage = snapshot.page
        hasNextPage = snapshot.hasNext
        state = .loaded(snapshot)
    }

    func applyLoadError(_ error: Error, appendingTo existingSnapshot: S?) {
        CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
        if let existingSnapshot {
            state = .loaded(existingSnapshot.withLoadMoreError(ErrorMessage.userFriendly(error)))
        } else {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }

    func setFailed(_ message: String) {
        state = .failed(message)
    }

    /// Subclasses override this to perform the actual data loading.
    /// Call `applyLoadResult` on success or `applyLoadError` on failure.
    func executeLoad(page: Int32, appendingTo existingSnapshot: S?, generation: Int) async {
        fatalError("Subclasses must override executeLoad")
    }
}

extension PaginatedViewModel.State {
    var isLoading: Bool {
        switch self {
        case .loading, .loadingMore:
            return true
        case .idle, .loaded, .failed:
            return false
        }
    }
}

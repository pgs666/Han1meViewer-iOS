import SwiftUI

enum PaginationState<Snapshot> {
    case idle
    case loading
    case loaded(Snapshot)
    case loadingMore(Snapshot)
    case failed(String)

    var isLoading: Bool {
        switch self {
        case .loading, .loadingMore:
            return true
        case .idle, .loaded, .failed:
            return false
        }
    }

    var loadedSnapshot: Snapshot? {
        switch self {
        case .loaded(let s), .loadingMore(let s):
            return s
        case .idle, .loading, .failed:
            return nil
        }
    }
}

func mergeByIdentifiable<T: Identifiable>(_ existing: [T], with newItems: [T]) -> [T] where T.ID == String {
    var seenIDs = Set(existing.map(\.id))
    var merged = existing
    for item in newItems where seenIDs.insert(item.id).inserted {
        merged.append(item)
    }
    return merged
}

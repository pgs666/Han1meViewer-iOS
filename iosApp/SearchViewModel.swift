import Foundation
import Han1meShared

@MainActor
final class SearchViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(SearchScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let searchFeature: SearchFeature

    init(searchFeature: SearchFeature) {
        self.searchFeature = searchFeature
    }

    func search(keyword: String) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            state = .idle
            return
        }
        guard case .loading = state else {
            state = .loading
            Task {
                await loadSearch(keyword: trimmedKeyword)
            }
            return
        }
    }

    private func loadSearch(keyword: String) async {
        do {
            let snapshot = try await searchFeature.search(keyword: keyword, page: 1)
            state = .loaded(SearchScreenSnapshot(snapshot))
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }
}

struct SearchScreenSnapshot {
    let results: [SearchVideoRow]

    init(_ snapshot: SearchSnapshot) {
        let count = Int(snapshot.itemCount())
        results = (0..<count).compactMap { index in
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

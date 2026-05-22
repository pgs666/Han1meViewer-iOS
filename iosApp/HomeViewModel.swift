import Foundation
import Han1meShared

@MainActor
final class HomeViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(HomeFeedSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let homeFeature = HomeFeature()

    func load() {
        guard case .loading = state else {
            state = .loading
            Task {
                await loadHome()
            }
            return
        }
    }

    private func loadHome() async {
        do {
            let snapshot = try await homeFeature.loadHome()
            state = .loaded(snapshot)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

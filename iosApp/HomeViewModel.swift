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
    @Published private(set) var smokeFetchSummary: String = "Smoke fetch pending"

    private let homeFeature = HomeFeature()
    private let smokeTest = SharedSmokeTest()

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
            let smokeResult = try await smokeTest.fetchSomething()
            smokeFetchSummary = "Smoke HTTP: \(smokeResult.sourceUrl), bytes: \(smokeResult.bodyLength)"
            let snapshot = try await homeFeature.loadHome()
            state = .loaded(snapshot)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

import Foundation
import Han1meShared

@MainActor
final class LoginViewModel: ObservableObject {
    enum State {
        case idle
        case submitting
        case succeeded(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let authFeature: AuthFeature

    init(authFeature: AuthFeature) {
        self.authFeature = authFeature
    }

    func login(email: String, password: String) {
        guard case .submitting = state else {
            state = .submitting
            Task {
                await submit(email: email, password: password)
            }
            return
        }
    }

    private func submit(email: String, password: String) async {
        do {
            let snapshot = try await authFeature.login(email: email, password: password)
            if snapshot.isLoggedIn {
                state = .succeeded(snapshot.message)
            } else {
                state = .failed(snapshot.message)
            }
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }
}

import Foundation
import Han1meShared

@MainActor
final class MineViewModel: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published private(set) var isCheckingLogin = false
    @Published private(set) var profile = MineProfileSnapshot()
    @Published private(set) var errorMessage: String?
    /// True when a background login check determined the saved session is
    /// no longer valid (expired / network) while we previously believed
    /// the user was logged in. Drives the in-card "请重新登录" hint without
    /// throwing the whole row back to the generic logged-out state.
    @Published private(set) var needsReLogin = false

    private static let loginCheckTimeoutNanoseconds: UInt64 = 20_000_000_000

    // Persistence keys — cache the last-known logged-in profile so the
    // account card renders the real user immediately on launch (no flash
    // of the "登录" placeholder) while the actual check runs in the
    // background.
    private enum Keys {
        static let wasLoggedIn = "mine_was_logged_in"
        static let username = "mine_cached_username"
        static let avatarUrl = "mine_cached_avatar_url"
    }

    private let webLoginFeature: WebLoginFeature
    private let homeFeature: HomeFeature
    private var didLoadLoginState = false
    private var sessionTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var logoutTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(webLoginFeature: WebLoginFeature, homeFeature: HomeFeature) {
        self.webLoginFeature = webLoginFeature
        self.homeFeature = homeFeature
        // Seed from the persisted snapshot so the card shows the saved
        // user straight away.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Keys.wasLoggedIn) {
            isLoggedIn = true
            profile = MineProfileSnapshot(
                username: defaults.string(forKey: Keys.username),
                avatarUrl: defaults.string(forKey: Keys.avatarUrl)
            )
        }
    }

    deinit {
        sessionTask?.cancel()
        profileTask?.cancel()
        logoutTask?.cancel()
    }

    func refreshLoginState(force: Bool = false) {
        guard !isCheckingLogin else {
            return
        }
        guard force || !didLoadLoginState else {
            return
        }

        didLoadLoginState = true
        // NOTE: isCheckingLogin only drives a small inline spinner now; the
        // card keeps showing the cached login state underneath it.
        isCheckingLogin = true
        errorMessage = nil
        sessionTask?.cancel()
        profileTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        sessionTask = Task { [weak self] in
            guard let self else { return }
            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.loginCheckTimeoutNanoseconds)
                guard !Task.isCancelled else { return }
                await self?.failLoginCheckOnTimeout(generation: generation)
            }
            defer {
                timeoutTask.cancel()
                if generation == requestGeneration {
                    isCheckingLogin = false
                }
            }
            do {
                let session = try await webLoginFeature.currentSessionSnapshot()
                guard !Task.isCancelled, generation == requestGeneration else { return }
                if session.isLoggedIn {
                    isLoggedIn = true
                    needsReLogin = false
                    AppLogger.log("login check: logged in")
                    await loadProfile(generation: generation)
                } else {
                    // Session gone. If we previously thought we were logged
                    // in, surface the in-card re-login hint instead of a
                    // silent flip.
                    let wasLoggedIn = isLoggedIn
                    isLoggedIn = false
                    profile = MineProfileSnapshot()
                    needsReLogin = wasLoggedIn
                    AppLogger.log("login check: not logged in (wasLoggedIn=\(wasLoggedIn))")
                    clearPersistedProfile()
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == requestGeneration else { return }
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                // Keep the cached logged-in card visible but mark that a
                // re-login may be needed; don't blow away the saved profile.
                if isLoggedIn {
                    needsReLogin = true
                }
                errorMessage = ErrorMessage.userFriendly(error)
            }
        }
    }

    func cancelSessionRefresh() {
        sessionTask?.cancel()
        profileTask?.cancel()
    }

    func markLoggedIn() {
        didLoadLoginState = true
        isLoggedIn = true
        needsReLogin = false
        profileTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        profileTask = Task { [weak self] in
            await self?.loadProfile(generation: generation)
        }
    }

    func logout(clearWebViewCookies: @escaping () async -> Void, onSuccess: @escaping () -> Void) {
        guard !isCheckingLogin else {
            return
        }

        isCheckingLogin = true
        errorMessage = nil
        sessionTask?.cancel()
        profileTask?.cancel()
        logoutTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        logoutTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == requestGeneration {
                    isCheckingLogin = false
                }
            }
            do {
                _ = try await webLoginFeature.logout()
                await clearWebViewCookies()
                guard !Task.isCancelled else { return }
                didLoadLoginState = true
                isLoggedIn = false
                needsReLogin = false
                profile = MineProfileSnapshot()
                clearPersistedProfile()
                onSuccess()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                errorMessage = ErrorMessage.userFriendly(error)
            }
        }
    }

    private func failLoginCheckOnTimeout(generation: Int) {
        guard generation == requestGeneration, isCheckingLogin else {
            return
        }
        requestGeneration += 1
        sessionTask?.cancel()
        profileTask?.cancel()
        isCheckingLogin = false
        // Don't tear down the cached card on a slow check — just hint that
        // a re-login may be needed if we were showing a logged-in state.
        if isLoggedIn {
            needsReLogin = true
        }
        errorMessage = String(localized: "error.timeout")
    }

    private func loadProfile(generation: Int) async {
        do {
            let home = try await homeFeature.loadHome()
            guard !Task.isCancelled, generation == requestGeneration else { return }
            profile = MineProfileSnapshot(
                username: home.username,
                avatarUrl: home.avatarUrl
            )
            persistProfile()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == requestGeneration else { return }
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
            errorMessage = ErrorMessage.userFriendly(error)
        }
    }

    private func persistProfile() {
        let defaults = UserDefaults.standard
        defaults.set(isLoggedIn, forKey: Keys.wasLoggedIn)
        defaults.set(profile.username, forKey: Keys.username)
        defaults.set(profile.avatarUrl, forKey: Keys.avatarUrl)
    }

    private func clearPersistedProfile() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: Keys.wasLoggedIn)
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.avatarUrl)
    }
}

struct MineProfileSnapshot {
    let username: String?
    let avatarUrl: String?

    init(username: String? = nil, avatarUrl: String? = nil) {
        self.username = username
        self.avatarUrl = avatarUrl
    }
}

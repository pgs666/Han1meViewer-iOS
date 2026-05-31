import SwiftUI
import WebKit
import Han1meShared

struct MineView: View {
    private let environment: SharedAppEnvironment

    init(environment: SharedAppEnvironment) {
        self.environment = environment
    }

    // IMPORTANT: MineView must NOT own or reference the MineViewModel.
    // It hosts the List whose NavigationLinks drive push transitions. If
    // MineView observed the view model, the async login check completing
    // mid-push (e.g. tapping 设置 right after opening Mine) would
    // invalidate MineView's whole body — rebuilding the navigating List
    // during the transition, which makes SwiftUI drop the push animation.
    // The view model lives entirely inside MineAccountSection, so the
    // check only re-renders that leaf row, never the navigating list.
    var body: some View {
        CompatibleNavigationStack {
            List {
                Section("主要") {
                    NavigationLink {
                        SettingsView(environment: environment)
                    } label: {
                        MineMenuRow(title: "设置", systemImage: "gearshape")
                    }
                }

                Section("我的列表") {
                    NavigationLink {
                        UserVideoListView(
                            title: String(localized: "稍后观看"),
                            emptyMessage: String(localized: "暂无稍后观看"),
                            feature: environment.watchLaterFeature(),
                            environment: environment
                        )
                    } label: {
                        MineMenuRow(title: "稍后观看", systemImage: "clock")
                    }
                    NavigationLink {
                        UserVideoListView(
                            title: String(localized: "收藏影片"),
                            emptyMessage: String(localized: "暂无收藏影片"),
                            feature: environment.favoriteVideoFeature(),
                            environment: environment
                        )
                    } label: {
                        MineMenuRow(title: "收藏影片", systemImage: "heart")
                    }
                    NavigationLink {
                        UserPlaylistView(
                            feature: environment.userPlaylistFeature(),
                            environment: environment
                        )
                    } label: {
                        MineMenuRow(title: "播放清单", systemImage: "list.bullet.rectangle")
                    }
                }

                Section("视频") {
                    NavigationLink {
                        OnlineWatchHistoryView(environment: environment)
                    } label: {
                        MineMenuRow(title: "在线历史", systemImage: "clock.arrow.circlepath")
                    }
                    NavigationLink {
                        WatchHistoryView(environment: environment)
                    } label: {
                        MineMenuRow(title: "本地历史", systemImage: "clock")
                    }
                    NavigationLink {
                        DownloadsView(environment: environment)
                    } label: {
                        MineMenuRow(title: "下载", systemImage: "arrow.down.circle")
                    }
                }
            }
            // The account card lives OUTSIDE the List (pinned above it) so
            // its background login check — which re-renders the card on
            // completion — never re-renders the List that owns the
            // NavigationLinks. A List-row re-render coinciding with a push
            // makes SwiftUI apply the push without animation (the reported
            // "destination appears instantly while the check runs" bug).
            .safeAreaInset(edge: .top, spacing: 0) {
                MineAccountSection(environment: environment)
            }
            .navigationTitle("我的")
            .logScreen("Mine")
        }
    }
}

/// Owns the MineViewModel and renders the account card + its alerts. Kept
/// separate from MineView so the login check (which mutates the view
/// model asynchronously) only re-renders this row, not the navigating
/// List — preserving NavigationLink push animations.
private struct MineAccountSection: View {
    private let environment: SharedAppEnvironment
    private let webLoginFeature: WebLoginFeature
    @StateObject private var viewModel: MineViewModel
    @State private var activeAlert: MineAlert?

    init(environment: SharedAppEnvironment) {
        self.environment = environment
        let webLoginFeature = environment.webLoginFeature()
        self.webLoginFeature = webLoginFeature
        _viewModel = StateObject(
            wrappedValue: MineViewModel(
                webLoginFeature: webLoginFeature,
                homeFeature: environment.homeFeature()
            )
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if viewModel.isLoggedIn {
                    Button {
                        activeAlert = .confirmLogout
                    } label: {
                        MineAccountRow(
                            isLoggedIn: true,
                            needsReLogin: viewModel.needsReLogin,
                            profile: viewModel.profile
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        LoginView(
                            webLoginFeature: webLoginFeature,
                            onLoginSuccess: {
                                viewModel.markLoggedIn()
                                activeAlert = .loginSuccess
                            }
                        )
                    } label: {
                        MineAccountRow(
                            isLoggedIn: false,
                            needsReLogin: viewModel.needsReLogin,
                            profile: viewModel.profile
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let message = viewModel.errorMessage, !viewModel.needsReLogin {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.systemGroupedBackground))
        .task {
            // Delay the first login check so it cannot fire its state
            // updates while the user is navigating away right after Mine
            // appears. If the check's objectWillChange lands in the same
            // update cycle as a NavigationLink push, SwiftUI applies the
            // push without animation. Giving the navigation a moment to
            // settle first avoids that. The check is silent, so the delay
            // is invisible.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            viewModel.refreshLoginState()
        }
        .onDisappear {
            viewModel.cancelSessionRefresh()
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .loginSuccess:
                return Alert(
                    title: Text("登录成功"),
                    message: Text("已同步网页登录状态。"),
                    dismissButton: .default(Text("好"))
                )
            case .confirmLogout:
                return Alert(
                    title: Text("退出登录"),
                    message: Text("确定要清除当前登录状态吗？"),
                    primaryButton: .destructive(Text("退出登录")) {
                        logout()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .loggedOut:
                return Alert(
                    title: Text("已退出登录"),
                    message: Text("本地登录状态已清除。"),
                    dismissButton: .default(Text("好"))
                )
            case .notMigrated(let title):
                return Alert(
                    title: Text(title),
                    message: Text("这个功能还没有迁移到 iOS，后续会按优先级接入真实实现。"),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private func logout() {
        viewModel.logout(
            clearWebViewCookies: clearWebViewCookies,
            onSuccess: {
                environment.clearCachedCurrentUserId()
                activeAlert = .loggedOut
            }
        )
    }

    private func clearWebViewCookies() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            clearHanimeWebViewCookies {
                continuation.resume()
            }
        }
    }

    private func clearHanimeWebViewCookies(completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let cookieStore = dataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            let hanimeCookies = cookies.filter { cookie in
                cookie.domain.contains("hanime1.me")
            }

            guard !hanimeCookies.isEmpty else {
                completion()
                return
            }

            let group = DispatchGroup()
            hanimeCookies.forEach { cookie in
                group.enter()
                cookieStore.delete(cookie) {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion()
            }
        }
    }
}

private enum MineAlert: Identifiable {
    case loginSuccess
    case confirmLogout
    case loggedOut
    case notMigrated(String)

    var id: String {
        switch self {
        case .loginSuccess:
            return "loginSuccess"
        case .confirmLogout:
            return "confirmLogout"
        case .loggedOut:
            return "loggedOut"
        case .notMigrated(let title):
            return "notMigrated-\(title)"
        }
    }
}

private struct MineAccountRow: View {
    let isLoggedIn: Bool
    let needsReLogin: Bool
    let profile: MineProfileSnapshot

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 42, height: 42)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(needsReLogin ? Color.red : Color.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        if needsReLogin {
            return String(localized: "登录已失效，请重新登录")
        }
        if isLoggedIn {
            return String(localized: "mine.login.logout_hint")
        }
        return String(localized: "mine.login.web_hint")
    }

    private var displayName: String {
        guard isLoggedIn else {
            return String(localized: "mine.account.login")
        }
        return profile.username?.isEmpty == false ? profile.username! : String(localized: "mine.account.logged_in")
    }

    @ViewBuilder
    private var avatar: some View {
        if isLoggedIn, let avatarUrl = profile.avatarUrl, !avatarUrl.isEmpty {
            CachedRemoteImage(urlString: avatarUrl, resizeWidth: 42)
        } else {
            ZStack {
                // Logged-in placeholder uses the neutral primary tint
                // (black/white adaptive) rather than the accent colour.
                Circle()
                    .fill(isLoggedIn ? Color.primary.opacity(0.08) : Color.accentColor.opacity(0.12))
                Image(systemName: isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle.badge.checkmark")
                    .foregroundStyle(isLoggedIn ? Color.primary : Color.accentColor)
                    .imageScale(.large)
            }
        }
    }
}

private struct MineMenuRow: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.primary)
    }
}

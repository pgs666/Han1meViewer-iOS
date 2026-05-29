import SwiftUI
import WebKit
import Han1meShared

struct MineView: View {
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
        CompatibleNavigationStack {
            List {
                Section {
                    if viewModel.isLoggedIn {
                        // Logged-in (or cached-as-logged-in): tapping the
                        // card logs out. The background check runs silently;
                        // only a small trailing spinner / re-login hint
                        // appears inside the card.
                        Button {
                            activeAlert = .confirmLogout
                        } label: {
                            MineAccountRow(
                                isLoggedIn: true,
                                isChecking: viewModel.isCheckingLogin,
                                needsReLogin: viewModel.needsReLogin,
                                profile: viewModel.profile
                            )
                        }
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
                                isChecking: viewModel.isCheckingLogin,
                                needsReLogin: viewModel.needsReLogin,
                                profile: viewModel.profile
                            )
                        }
                    }
                }

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
                            title: "稍后观看",
                            emptyMessage: "暂无稍后观看",
                            feature: environment.watchLaterFeature(),
                            environment: environment
                        )
                    } label: {
                        MineMenuRow(title: "稍后观看", systemImage: "clock")
                    }
                    NavigationLink {
                        UserVideoListView(
                            title: "收藏影片",
                            emptyMessage: "暂无收藏影片",
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

                // Only show the generic error banner for errors that the
                // account card isn't already surfacing (the card shows its
                // own "请重新登录" hint when needsReLogin is set).
                if let message = viewModel.errorMessage, !viewModel.needsReLogin {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("我的")
            .task {
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
    let isChecking: Bool
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

            // Background-check indicator lives inside the card on the right,
            // so the login verification never blocks or reshuffles the UI.
            if isChecking {
                ProgressView()
                    .controlSize(.small)
            }
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
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.primary)
    }
}

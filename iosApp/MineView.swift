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
        NavigationView {
            List {
                Section {
                    if viewModel.isLoggedIn {
                        Button {
                            activeAlert = .confirmLogout
                        } label: {
                            MineAccountRow(
                                isLoggedIn: viewModel.isLoggedIn,
                                isChecking: viewModel.isCheckingLogin,
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
                                isLoggedIn: viewModel.isLoggedIn,
                                isChecking: viewModel.isCheckingLogin,
                                profile: viewModel.profile
                            )
                        }
                    }
                }

                Section("主要") {
                    Button {
                        activeAlert = .notMigrated("设置")
                    } label: {
                        MineMenuRow(title: "设置", systemImage: "gearshape")
                    }
                    Button {
                        activeAlert = .notMigrated("每日签到")
                    } label: {
                        MineMenuRow(title: "每日签到", systemImage: "hand.thumbsup")
                    }
                }

                Section("我的列表") {
                    Button {
                        activeAlert = .notMigrated("稍后观看")
                    } label: {
                        MineMenuRow(title: "稍后观看", systemImage: "clock")
                    }
                    Button {
                        activeAlert = .notMigrated("收藏影片")
                    } label: {
                        MineMenuRow(title: "收藏影片", systemImage: "heart")
                    }
                    Button {
                        activeAlert = .notMigrated("播放清单")
                    } label: {
                        MineMenuRow(title: "播放清单", systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink {
                        FollowingView(environment: environment)
                    } label: {
                        MineMenuRow(title: "我的订阅", systemImage: "person.2")
                    }
                }

                Section("视频") {
                    NavigationLink {
                        WatchHistoryView(environment: environment)
                    } label: {
                        MineMenuRow(title: "观看历史", systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        activeAlert = .notMigrated("下载")
                    } label: {
                        MineMenuRow(title: "下载", systemImage: "arrow.down.circle")
                    }
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("我的")
            .onAppear {
                viewModel.refreshLoginState()
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
        .navigationViewStyle(.stack)
    }

    private func logout() {
        viewModel.logout(
            clearWebViewCookies: clearWebViewCookies,
            onSuccess: {
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
    let profile: MineProfileSnapshot

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 42, height: 42)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .foregroundColor(.primary)
                Text(isChecking ? "正在检查登录状态" : (isLoggedIn ? "点击可退出登录" : "使用网页登录并同步 Cookie"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var displayName: String {
        guard isLoggedIn else {
            return "账户登录"
        }
        return profile.username?.isEmpty == false ? profile.username! : "已登录"
    }

    @ViewBuilder
    private var avatar: some View {
        if isLoggedIn, let avatarUrl = profile.avatarUrl, !avatarUrl.isEmpty {
            CachedRemoteImage(urlString: avatarUrl)
        } else {
            ZStack {
                Circle()
                    .fill(isLoggedIn ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.12))
                Image(systemName: isLoggedIn ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.badge.checkmark")
                    .foregroundColor(isLoggedIn ? .green : .accentColor)
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
            .foregroundColor(.primary)
    }
}

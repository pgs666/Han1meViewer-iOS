import SwiftUI
import WebKit
import Han1meShared

struct MineView: View {
    let webLoginFeature: WebLoginFeature

    @State private var isLoggedIn = false
    @State private var isCheckingLogin = false
    @State private var activeAlert: MineAlert?

    var body: some View {
        NavigationView {
            List {
                Section {
                    if isLoggedIn {
                        Button {
                            activeAlert = .confirmLogout
                        } label: {
                            MineAccountRow(
                                isLoggedIn: isLoggedIn,
                                isChecking: isCheckingLogin
                            )
                        }
                    } else {
                        NavigationLink {
                            LoginView(
                                webLoginFeature: webLoginFeature,
                                onLoginSuccess: {
                                    isLoggedIn = true
                                    activeAlert = .loginSuccess
                                }
                            )
                        } label: {
                            MineAccountRow(
                                isLoggedIn: isLoggedIn,
                                isChecking: isCheckingLogin
                            )
                        }
                    }
                }

                Section("主要") {
                    MineMenuRow(title: "设置", systemImage: "gearshape")
                    MineMenuRow(title: "每日签到", systemImage: "hand.thumbsup")
                }

                Section("我的列表") {
                    MineMenuRow(title: "稍后观看", systemImage: "clock")
                    MineMenuRow(title: "收藏影片", systemImage: "heart")
                    MineMenuRow(title: "播放清单", systemImage: "list.bullet.rectangle")
                    MineMenuRow(title: "我的订阅", systemImage: "person.2")
                }

                Section("视频") {
                    MineMenuRow(title: "观看历史", systemImage: "clock.arrow.circlepath")
                    MineMenuRow(title: "下载", systemImage: "arrow.down.circle")
                }
            }
            .navigationTitle("我的")
            .onAppear {
                refreshLoginState()
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
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func refreshLoginState() {
        guard !isCheckingLogin else {
            return
        }

        isCheckingLogin = true
        Task {
            do {
                let snapshot = try await webLoginFeature.currentSessionSnapshot()
                await MainActor.run {
                    isLoggedIn = snapshot.isLoggedIn
                    isCheckingLogin = false
                }
            } catch {
                await MainActor.run {
                    isCheckingLogin = false
                }
            }
        }
    }

    private func logout() {
        isCheckingLogin = true
        Task {
            do {
                _ = try await webLoginFeature.logout()
                await clearWebViewCookies()
                await MainActor.run {
                    isLoggedIn = false
                    isCheckingLogin = false
                    activeAlert = .loggedOut
                }
            } catch {
                await MainActor.run {
                    isCheckingLogin = false
                }
            }
        }
    }

    private func clearWebViewCookies() async {
        await withCheckedContinuation { continuation in
            let dataStore = WKWebsiteDataStore.default()
            let cookieStore = dataStore.httpCookieStore
            cookieStore.getAllCookies { cookies in
                let hanimeCookies = cookies.filter { cookie in
                    cookie.domain.contains("hanime1.me")
                }

                guard !hanimeCookies.isEmpty else {
                    continuation.resume()
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
                    continuation.resume()
                }
            }
        }
    }
}

private enum MineAlert: Identifiable {
    case loginSuccess
    case confirmLogout
    case loggedOut

    var id: String {
        switch self {
        case .loginSuccess:
            return "loginSuccess"
        case .confirmLogout:
            return "confirmLogout"
        case .loggedOut:
            return "loggedOut"
        }
    }
}

private struct MineAccountRow: View {
    let isLoggedIn: Bool
    let isChecking: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isLoggedIn ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.badge.checkmark")
                .foregroundColor(isLoggedIn ? .green : .accentColor)
                .imageScale(.large)

            VStack(alignment: .leading, spacing: 3) {
                Text(isLoggedIn ? "已登录" : "账户登录")
                    .foregroundColor(.primary)
                Text(isChecking ? "正在检查登录状态" : (isLoggedIn ? "点击可退出登录" : "使用网页登录并同步 Cookie"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
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

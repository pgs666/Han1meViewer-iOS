import SwiftUI
import Han1meShared

struct MineView: View {
    let webLoginFeature: WebLoginFeature

    @State private var isLoggedIn = false
    @State private var isCheckingLogin = false
    @State private var showLoginSuccessAlert = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink {
                        LoginView(
                            webLoginFeature: webLoginFeature,
                            onLoginSuccess: {
                                isLoggedIn = true
                                showLoginSuccessAlert = true
                            }
                        )
                    } label: {
                        MineAccountRow(
                            isLoggedIn: isLoggedIn,
                            isChecking: isCheckingLogin
                        )
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
            .alert(isPresented: $showLoginSuccessAlert) {
                Alert(
                    title: Text("登录成功"),
                    message: Text("已同步网页登录状态。"),
                    dismissButton: .default(Text("好"))
                )
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
                Text(isChecking ? "正在检查登录状态" : (isLoggedIn ? "网页登录状态已同步" : "使用网页登录并同步 Cookie"))
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

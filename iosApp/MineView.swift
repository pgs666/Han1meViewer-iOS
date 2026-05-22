import SwiftUI
import Han1meShared

struct MineView: View {
    let authFeature: AuthFeature

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink {
                        LoginView(authFeature: authFeature)
                    } label: {
                        Label("账户登录", systemImage: "person.crop.circle.badge.checkmark")
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
        }
        .navigationViewStyle(.stack)
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

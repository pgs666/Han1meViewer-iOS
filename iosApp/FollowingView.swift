import SwiftUI

struct FollowingView: View {
    var body: some View {
        NavigationView {
            List {
                Section("关注") {
                    Label("订阅作者", systemImage: "person.2")
                    Label("关注更新", systemImage: "bell")
                }

                Section {
                    Text("登录后这里会显示你关注的作者和更新。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("关注")
        }
        .navigationViewStyle(.stack)
    }
}

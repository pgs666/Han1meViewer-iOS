import SwiftUI
import Han1meShared

@main
struct Han1meViewerApp: App {
    private let sharedEnvironment = SharedAppEnvironment(driverFactory: DatabaseDriverFactory())
    @State private var selectedTab: MainTab = .home

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if #available(iOS 26.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
    }

    @available(iOS 26.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("首页", systemImage: "house.fill", value: MainTab.home) {
                HomeView(environment: sharedEnvironment)
            }

            Tab("关注", systemImage: "heart.fill", value: MainTab.following) {
                FollowingView(environment: sharedEnvironment)
            }

            Tab("我的", systemImage: "person.crop.circle.fill", value: MainTab.mine) {
                MineView(environment: sharedEnvironment)
            }

            Tab("搜索", systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                SearchView(environment: sharedEnvironment)
            }
        }
        .tint(.red)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            NowPlayingAccessory()
        }
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(environment: sharedEnvironment)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(MainTab.home)

            FollowingView(environment: sharedEnvironment)
                .tabItem {
                    Label("关注", systemImage: "heart")
                }
                .tag(MainTab.following)

            MineView(environment: sharedEnvironment)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
                .tag(MainTab.mine)

            SearchView(environment: sharedEnvironment)
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(MainTab.search)
        }
        .tint(.red)
    }
}

private enum MainTab: Hashable {
    case home
    case following
    case mine
    case search
}

@available(iOS 26.0, *)
private struct NowPlayingAccessory: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.78),
                            Color.pink.opacity(0.58),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Han1meViewer")
                    .font(.headline)
                    .lineLimit(1)
                Text("继续浏览")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
            } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
            }

            Button {
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
    }
}

import SwiftUI
import Han1meShared

@main
struct Han1meViewerApp: App {
    private let sharedEnvironment = SharedAppEnvironment(driverFactory: DatabaseDriverFactory())

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView(environment: sharedEnvironment)
                    .tabItem {
                        Label("首页", systemImage: "house")
                    }

                FollowingView(environment: sharedEnvironment)
                    .tabItem {
                        Label("关注", systemImage: "heart")
                    }

                MineView(environment: sharedEnvironment)
                    .tabItem {
                        Label("我的", systemImage: "person.crop.circle")
                    }

                SearchView(environment: sharedEnvironment)
                    .tabItem {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
            }
        }
    }
}

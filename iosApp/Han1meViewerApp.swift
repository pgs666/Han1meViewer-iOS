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

                FollowingView()
                    .tabItem {
                        Label("关注", systemImage: "heart")
                    }

                MineView(authFeature: sharedEnvironment.authFeature())
                    .tabItem {
                        Label("我的", systemImage: "person.crop.circle")
                    }

                SearchView()
                    .tabItem {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
            }
        }
    }
}

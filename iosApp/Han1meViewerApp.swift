import SwiftUI
import Han1meShared

@main
struct Han1meViewerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let sharedEnvironment = SharedAppEnvironment(driverFactory: DatabaseDriverFactory())
    @State private var selectedTab: MainTab = .home
    @State private var searchLaunchRequest: SearchLaunchRequest?

    var body: some Scene {
        WindowGroup {
            rootView
                .modifier(
                    CloudflareChallengePresenter(
                        cloudflareFeature: sharedEnvironment.cloudflareFeature()
                    )
                )
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
                HomeView(environment: sharedEnvironment) { section in
                    searchLaunchRequest = SearchLaunchRequest(sectionKey: section.key, sectionTitle: section.title)
                    selectedTab = .search
                }
            }

            Tab("关注", systemImage: "heart.fill", value: MainTab.following) {
                FollowingView(environment: sharedEnvironment)
            }

            Tab("我的", systemImage: "person.crop.circle.fill", value: MainTab.mine) {
                MineView(environment: sharedEnvironment)
            }

            Tab("搜索", systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                SearchView(environment: sharedEnvironment, launchRequest: $searchLaunchRequest)
            }
        }
        .tint(.red)
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(environment: sharedEnvironment) { section in
                searchLaunchRequest = SearchLaunchRequest(sectionKey: section.key, sectionTitle: section.title)
                selectedTab = .search
            }
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

            SearchView(environment: sharedEnvironment, launchRequest: $searchLaunchRequest)
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

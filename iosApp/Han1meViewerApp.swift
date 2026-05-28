import SwiftUI
import Han1meShared

@main
struct Han1meViewerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let sharedEnvironment = SharedAppEnvironment(driverFactory: DatabaseDriverFactory(), preferencesStorage: IosPreferencesStorage(), baseUrl: "https://hanime1.me")
    @StateObject private var tabBarVisibility = TabBarVisibilityController()
    @State private var selectedTab: MainTab = .home
    @State private var searchLaunchRequest: SearchLaunchRequest?
    @State private var deepLinkedVideo: DeepLinkedVideo?
    /// Each root tab tracks an ever-changing identity. Tapping any tab
    /// — including the currently selected one — bumps that tab's id,
    /// which forces SwiftUI to teardown the entire NavigationStack
    /// inside it (root view + every pushed sub-page like
    /// VideoDetailView), then rebuild a fresh root. Two effects:
    /// 1. Tab-bar tap always returns to the tab's root, never lands on
    ///    a leftover pushed page.
    /// 2. Pushed sub-pages are released, freeing their resources
    ///    (e.g. KSPlayerLayer, scroll caches), so the app doesn't
    ///    accumulate memory across tab visits.
    @State private var homeTabResetID = UUID()
    @State private var followingTabResetID = UUID()
    @State private var mineTabResetID = UUID()
    @State private var searchTabResetID = UUID()

    /// Binding wrapper around `selectedTab`. SwiftUI calls `.set` even
    /// when the user taps the already-selected tab, so we use this to
    /// detect every tab-tap and bump that tab's `.id` regardless of
    /// whether selection actually changed.
    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                bumpResetID(for: newValue)
                selectedTab = newValue
            }
        )
    }

    private func bumpResetID(for tab: MainTab) {
        switch tab {
        case .home:      homeTabResetID = UUID()
        case .following: followingTabResetID = UUID()
        case .mine:      mineTabResetID = UUID()
        case .search:    searchTabResetID = UUID()
        }
    }

    init() {
        CrashReporter.install()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(tabBarVisibility)
                .environment(\.searchFeature, sharedEnvironment.searchFeature())
                .onReceive(NotificationCenter.default.publisher(for: SearchNavigationCenter.requestNotification)) { notification in
                    if let keyword = notification.userInfo?[SearchNavigationCenter.keywordKey] as? String {
                        openSearch(keyword: keyword)
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .sheet(item: $deepLinkedVideo) { item in
                    CompatibleNavigationStack {
                        VideoDetailView(
                            videoCode: item.videoCode,
                            videoFeature: sharedEnvironment.videoFeature(),
                            commentFeature: sharedEnvironment.commentFeature()
                        )
                    }
                }
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
        TabView(selection: tabSelection) {
            Tab("首页", systemImage: "house.fill", value: MainTab.home) {
                HomeView(environment: sharedEnvironment) { section in
                    searchLaunchRequest = SearchLaunchRequest(sectionKey: section.key, sectionTitle: section.title)
                    selectedTab = .search
                }
                .id(homeTabResetID)
            }

            Tab("关注", systemImage: "heart.fill", value: MainTab.following) {
                FollowingView(environment: sharedEnvironment)
                    .id(followingTabResetID)
            }

            Tab("我的", systemImage: "person.crop.circle.fill", value: MainTab.mine) {
                MineView(environment: sharedEnvironment)
                    .id(mineTabResetID)
            }

            Tab("搜索", systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                SearchView(environment: sharedEnvironment, launchRequest: $searchLaunchRequest)
                    .id(searchTabResetID)
            }
        }
        .tint(.red)
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var legacyTabView: some View {
        TabView(selection: tabSelection) {
            HomeView(environment: sharedEnvironment) { section in
                searchLaunchRequest = SearchLaunchRequest(sectionKey: section.key, sectionTitle: section.title)
                selectedTab = .search
            }
                .id(homeTabResetID)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(MainTab.home)

            FollowingView(environment: sharedEnvironment)
                .id(followingTabResetID)
                .tabItem {
                    Label("关注", systemImage: "heart")
                }
                .tag(MainTab.following)

            MineView(environment: sharedEnvironment)
                .id(mineTabResetID)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
                .tag(MainTab.mine)

            SearchView(environment: sharedEnvironment, launchRequest: $searchLaunchRequest)
                .id(searchTabResetID)
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(MainTab.search)
        }
        .tint(.red)
    }

    private func handleDeepLink(_ url: URL) {
        if let videoCode = DeepLinkParser.videoCode(from: url) {
            deepLinkedVideo = DeepLinkedVideo(videoCode: videoCode)
            return
        }

        if let keyword = DeepLinkParser.searchKeyword(from: url) {
            openSearch(keyword: keyword)
        }
    }

    private func openSearch(keyword: String) {
        searchLaunchRequest = SearchLaunchRequest(sectionKey: "keyword", sectionTitle: keyword, keyword: keyword)
        selectedTab = .search
    }
}

private enum MainTab: Hashable {
    case home
    case following
    case mine
    case search
}

private struct DeepLinkedVideo: Identifiable {
    let videoCode: String

    var id: String { videoCode }
}

private enum DeepLinkParser {
    static func videoCode(from url: URL) -> String? {
        if let queryVideoCode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "v" || $0.name == "video" || $0.name == "videoCode" })?
            .value?
            .trimmedNonEmpty {
            return queryVideoCode
        }

        let pathParts = url.pathComponents.filter { $0 != "/" }
        if let markerIndex = pathParts.firstIndex(where: { ["watch", "videos", "video"].contains($0.lowercased()) }),
           pathParts.indices.contains(markerIndex + 1) {
            return pathParts[markerIndex + 1].trimmedNonEmpty
        }

        if ["han1me", "hanimeviewer"].contains(url.scheme?.lowercased() ?? ""),
           let host = url.host?.trimmedNonEmpty {
            if host.allSatisfy({ $0.isNumber }) {
                return host
            }
            if ["watch", "videos", "video"].contains(host.lowercased()) {
                return pathParts.first?.trimmedNonEmpty
            }
        }

        return nil
    }

    static func searchKeyword(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "q" || $0.name == "keyword" || $0.name == "search" })?
            .value?
            .trimmedNonEmpty
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

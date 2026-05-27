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

    init() {
        CrashReporter.install()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(tabBarVisibility)
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
        .toolbar(tabBarVisibility.visibility, for: .tabBar)
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
        .toolbar(tabBarVisibility.visibility, for: .tabBar)
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

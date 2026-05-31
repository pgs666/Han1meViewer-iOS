import SwiftUI
import UIKit
import Han1meShared

@main
struct Han1meViewerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let sharedEnvironment = SharedAppEnvironment(driverFactory: DatabaseDriverFactory(), preferencesStorage: IosPreferencesStorage(), baseUrl: AppDomain.currentBaseURL)
    @StateObject private var tabBarVisibility = TabBarVisibilityController()
    @State private var selectedTab: MainTab = .home
    @State private var searchLaunchRequest: SearchLaunchRequest?
    @State private var deepLinkedVideo: DeepLinkedVideo?
    /// Per-tab "pop to root" signal. Tapping ANY tab — including the
    /// currently selected one — bumps that tab's signal, which a hidden
    /// helper (PopToRootOnSignal) inside that tab observes and uses to
    /// pop the enclosing UINavigationController back to its root view
    /// controller. Pushed sub-pages (e.g. VideoDetailView) are deinit'd
    /// and their resources released; the tab's root view itself is NOT
    /// rebuilt.
    @State private var homeTabPopSignal = UUID()
    @State private var followingTabPopSignal = UUID()
    @State private var mineTabPopSignal = UUID()
    @State private var searchTabPopSignal = UUID()

    /// Binding wrapper around `selectedTab`. SwiftUI calls `.set` even
    /// when the user taps the already-selected tab, so we use this to
    /// detect every tab-tap and bump that tab's pop signal regardless
    /// of whether selection actually changed.
    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                // Only bump the pop-to-root signal when the user RE-TAPS the
                // already-selected tab. Bumping on a real tab switch mutates
                // a @State right as the destination tab's NavigationStack is
                // appearing, and that state change breaks the first push
                // animation on the newly shown tab until it settles (most
                // visible on Mine, whose static list is tappable immediately
                // — other tabs only become tappable after their content
                // loads, by which point the stack has settled).
                if newValue == selectedTab {
                    bumpPopSignal(for: newValue)
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    private func bumpPopSignal(for tab: MainTab) {
        switch tab {
        case .home:      homeTabPopSignal = UUID()
        case .following: followingTabPopSignal = UUID()
        case .mine:      mineTabPopSignal = UUID()
        case .search:    searchTabPopSignal = UUID()
        }
    }

    init() {
        CrashReporter.install()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.tabBarVisibility, tabBarVisibility)
                .environment(\.searchFeature, sharedEnvironment.searchFeature())
                .onAppear {
                    DownloadManager.shared.configure(environment: sharedEnvironment)
                    AppLogger.log("app launched ios=\(UIDevice.current.systemVersion)")
                }
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
                HomeView(environment: sharedEnvironment)
                    .popsToRootWhen(signal: homeTabPopSignal)
            }

            Tab("关注", systemImage: "heart.fill", value: MainTab.following) {
                FollowingView(environment: sharedEnvironment)
                    .popsToRootWhen(signal: followingTabPopSignal)
            }

            Tab("我的", systemImage: "person.crop.circle.fill", value: MainTab.mine) {
                MineView(environment: sharedEnvironment)
                    .popsToRootWhen(signal: mineTabPopSignal)
            }

            Tab("搜索", systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                // NOTE: no .popsToRootWhen here. The PopToRootOnSignal helper
                // is a .background(UIViewControllerRepresentable) which, on the
                // iOS 26 search-role tab, disrupts the system's integrated
                // search-field layout (the search box renders wrong). The
                // search tab rarely needs the tap-to-pop behaviour anyway.
                SearchView(environment: sharedEnvironment, launchRequest: $searchLaunchRequest)
            }
        }
        .tint(.red)
        // Keep the tab bar fully expanded while scrolling (do NOT collapse
        // it into the minimized pill on scroll-down) per user preference.
        .tabBarMinimizeBehavior(.never)
    }

    private var legacyTabView: some View {
        TabView(selection: tabSelection) {
            HomeView(environment: sharedEnvironment)
                .popsToRootWhen(signal: homeTabPopSignal)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(MainTab.home)

            FollowingView(environment: sharedEnvironment)
                .popsToRootWhen(signal: followingTabPopSignal)
                .tabItem {
                    Label("关注", systemImage: "heart")
                }
                .tag(MainTab.following)

            MineView(environment: sharedEnvironment)
                .popsToRootWhen(signal: mineTabPopSignal)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
                .tag(MainTab.mine)

            SearchView(environment: sharedEnvironment, launchRequest: $searchLaunchRequest)
                .popsToRootWhen(signal: searchTabPopSignal)
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

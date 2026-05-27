import SwiftUI

struct CompatibleNavigationStack<Content: View>: View {
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityController
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            // iOS 17+: container-level toolbar binding drives animated
            // tab-bar slide via TabBarVisibilityController. Verified working
            // on iOS 26.5; the modifier composition does NOT trigger the
            // navigation-layout race seen on iPadOS 16.
            NavigationStack {
                content()
                    .toolbar(tabBarVisibility.visibility, for: .tabBar)
            }
        } else if #available(iOS 16.0, *) {
            // iPadOS 16: applying .toolbar(_:for: .tabBar) on the
            // NavigationStack root content causes severe layout corruption
            // (navigation bar / list section header overlap) and the entire
            // page becomes unresponsive. Fall back to NavigationStack
            // without the container-level toolbar binding — destination
            // views (VideoDetailView, SettingsView) still apply
            // .toolbar(.hidden, for: .tabBar) directly via
            // hidesTabBarOnAppear()'s iOS-16 branch, which is the
            // pre-animation behavior (correct, just no slide animation).
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
            .navigationViewStyle(.stack)
        }
    }
}

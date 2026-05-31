import SwiftUI

struct CompatibleNavigationStack<Content: View>: View {
    @Environment(\.tabBarVisibility) private var injected: TabBarVisibilityController?
    @StateObject private var fallback = TabBarVisibilityController()
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var controller: TabBarVisibilityController { injected ?? fallback }

    var body: some View {
        if #available(iOS 17.0, *) {
            // iOS 17+: container-level toolbar binding drives animated
            // tab-bar slide via TabBarVisibilityController. Verified working
            // on iOS 26.5; the modifier composition does NOT trigger the
            // navigation-layout race seen on iPadOS 16.
            //
            // Routed through ObservedNavigationStack so changes to the
            // controller's @Published `visibility` actually re-render the
            // toolbar binding — @Environment-injected ObservableObjects
            // don't auto-track @Published the way @EnvironmentObject would,
            // so we re-establish reactivity via @ObservedObject inside.
            ObservedNavigationStack(controller: controller, content: content)
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

@available(iOS 17.0, *)
private struct ObservedNavigationStack<Content: View>: View {
    @ObservedObject var controller: TabBarVisibilityController
    let content: () -> Content

    var body: some View {
        // [ISOLATION TEST] toolbar(visibility, for: .tabBar) binding removed
        // to check whether observing the shared tabBarVisibility controller
        // is what makes an early push (before the stack settles) skip its
        // animation. If the push animates now, this binding is the cause.
        NavigationStack {
            content()
        }
    }
}

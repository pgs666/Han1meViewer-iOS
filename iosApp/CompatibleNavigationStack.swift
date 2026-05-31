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
            // [ISOLATION TEST] Bypass ObservedNavigationStack entirely — no
            // observation of the shared tabBarVisibility controller, no
            // .toolbar(_, for: .tabBar) binding. Pure NavigationStack. If the
            // Mine push animates now (even when switching to Mine and tapping
            // immediately), the cause is the container observing the shared
            // controller; the tab bar just won't hide on push in this build.
            NavigationStack {
                content()
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

@available(iOS 17.0, *)
private struct ObservedNavigationStack<Content: View>: View {
    @ObservedObject var controller: TabBarVisibilityController
    let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .toolbar(controller.visibility, for: .tabBar)
        }
    }
}

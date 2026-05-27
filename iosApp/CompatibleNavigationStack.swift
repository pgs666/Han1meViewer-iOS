import SwiftUI

struct CompatibleNavigationStack<Content: View>: View {
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityController
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
                    // SwiftUI's recommended placement for tab-bar visibility
                    // control is INSIDE the NavigationStack on the root content
                    // (so the stack itself drives the tab bar layout pass).
                    // Putting it on TabView doesn't reliably trigger a slide
                    // animation when child pages flip the visibility.
                    .toolbar(tabBarVisibility.visibility, for: .tabBar)
            }
        } else {
            NavigationView {
                content()
            }
            .navigationViewStyle(.stack)
        }
    }
}

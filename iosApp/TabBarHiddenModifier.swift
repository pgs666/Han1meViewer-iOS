import SwiftUI

extension View {
    /// Hide the surrounding TabView's tab bar for the current pushed view.
    ///
    /// Picks the API based on runtime iOS version:
    /// - **iOS 18+**: `.toolbarVisibility(.hidden, for: .tabBar)`. The new
    ///   modifier is the path the system honors with an implicit slide-out
    ///   animation when NavigationStack pushes a child view that opts in
    ///   to hiding the tab bar.
    /// - **iOS 16–17**: falls back to `.toolbar(.hidden, for: .tabBar)`,
    ///   which works correctly but generally without animation. Older
    ///   deployment users still get the right visual; newer users get the
    ///   animation.
    @ViewBuilder
    func hidesTabBar() -> some View {
        if #available(iOS 18.0, *) {
            self.toolbarVisibility(.hidden, for: .tabBar)
        } else {
            self.toolbar(.hidden, for: .tabBar)
        }
    }
}

import SwiftUI

/// Shared state for the global tab-bar visibility, driven by pushed sub-pages
/// (e.g. video detail, settings) calling `acquireHidden(...)` / `release(...)`
/// on appear / disappear.
///
/// **Only used on iOS 17+.** On iPadOS 16 attaching
/// `.toolbar(visibility, for: .tabBar)` to the NavigationStack root content
/// causes severe layout corruption (overlapping nav bar with list rows /
/// section headers) and the page becomes unresponsive. iOS 16 therefore
/// falls back to the destination-level `.toolbar(.hidden, for: .tabBar)`
/// — correct visual outcome, just without the slide animation.
@MainActor
final class TabBarVisibilityController: ObservableObject {
    @Published var visibility: Visibility = .visible

    /// Reference count of pushed sub-pages currently asking the tab bar to
    /// stay hidden. Multiple-level pushes (e.g. detail → another detail) keep
    /// the tab bar hidden until the whole chain pops.
    private var hiddenRequesters: Int = 0

    func acquireHidden(animated: Bool = true) {
        hiddenRequesters += 1
        let target: Visibility = .hidden
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                visibility = target
            }
        } else {
            visibility = target
        }
    }

    func release(animated: Bool = true) {
        hiddenRequesters = max(0, hiddenRequesters - 1)
        guard hiddenRequesters == 0 else { return }
        let target: Visibility = .visible
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                visibility = target
            }
        } else {
            visibility = target
        }
    }
}

extension View {
    /// Sub-page convenience: hide the tab bar on appear and restore it on
    /// disappear.
    ///
    /// On iOS 17+ this uses the shared `TabBarVisibilityController` so the
    /// flip happens via `withAnimation`, producing a slide.
    ///
    /// On iPadOS 16 the controller path causes a layout-corruption /
    /// unresponsive-page bug, so we fall back to the simpler destination
    /// `.toolbar(.hidden, for: .tabBar)` (no animation, but correct).
    @MainActor
    func hidesTabBarOnAppear() -> some View {
        modifier(HidesTabBarModifier())
    }
}

private struct HidesTabBarModifier: ViewModifier {
    @Environment(\.tabBarVisibility) private var injected: TabBarVisibilityController?
    @StateObject private var fallback = TabBarVisibilityController()

    private var controller: TabBarVisibilityController { injected ?? fallback }

    func body(content: Content) -> some View {
        // [ISOLATION TEST] All versions now use the destination-level
        // .toolbar(.hidden, for: .tabBar) that iPadOS 16 already used —
        // iPadOS 16.6.1 does NOT exhibit the lost-push-animation bug, and
        // the only difference was that iOS 17+ instead mutated the
        // App-level @StateObject tabBarVisibility on .onAppear, which
        // re-evaluates the whole App body right as the just-switched-to
        // tab's NavigationStack is appearing — breaking its first push.
        content
            .toolbar(.hidden, for: .tabBar)
    }
}

/// Optional environment slot for the shared TabBarVisibilityController.
///
/// Why optional + custom EnvironmentKey instead of @EnvironmentObject:
/// SwiftUI's @EnvironmentObject crashes with "missing EnvironmentObject"
/// in any view rendered without that object having been injected. On
/// iOS 26 beta, sheet/.fullScreenCover content does NOT automatically
/// inherit @EnvironmentObject from its presenting view — so views like
/// CompatibleNavigationStack that read this controller would crash when
/// used inside such modal content (observed via crash trace where
/// SheetBridge.preferencesDidChange → CompatibleNavigationStack.body
/// → EnvironmentObject.error()).
///
/// With this optional Environment slot, those views read via
/// @Environment(\.tabBarVisibility) + a private @StateObject fallback,
/// so they degrade gracefully to a per-instance controller when nothing
/// has been injected. The app root injects the real shared one via
/// `.environment(\.tabBarVisibility, ...)` for the main UI tree.
private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: TabBarVisibilityController? = nil
}

extension EnvironmentValues {
    var tabBarVisibility: TabBarVisibilityController? {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

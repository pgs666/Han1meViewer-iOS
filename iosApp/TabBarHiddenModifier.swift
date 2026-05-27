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
    @EnvironmentObject private var controller: TabBarVisibilityController

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                // Animate BOTH directions. NavigationStack's push transition
                // does NOT carry a tab-bar slide for free, so we drive it
                // explicitly via withAnimation in the controller.
                .onAppear { controller.acquireHidden(animated: true) }
                .onDisappear { controller.release(animated: true) }
        } else {
            // iPadOS 16: the controller-driven container approach corrupts
            // layout. Fall back to direct destination-level hide.
            content
                .toolbar(.hidden, for: .tabBar)
        }
    }
}

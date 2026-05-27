import SwiftUI

/// Shared state for the global tab-bar visibility, driven by pushed sub-pages
/// (e.g. video detail, settings) calling `acquireHidden(...)` / `release(...)`
/// on appear / disappear.
///
/// Why an external observable instead of `.toolbar(.hidden, for: .tabBar)`
/// directly on the sub-page:
///
/// SwiftUI's runtime does not reliably animate the tab-bar transition when a
/// `.toolbar(_:for:)` modifier is applied to the destination view inside a
/// NavigationStack push (verified bug-class on iOS 16–26 across versions).
/// The well-known working pattern (Stack Overflow / community-vetted) is:
///   • Hold `Visibility` as `@State` at a higher level.
///   • Apply `.toolbar(visibility, for: .tabBar)` to the NavigationStack
///     container, NOT the destination view.
///   • Toggle the @State inside `withAnimation { … }` from the destination's
///     `.onAppear` / `.onDisappear`.
/// SwiftUI then animates the tab-bar slide because the change is bound to
/// the NavigationStack's own layout pass.
///
/// Putting the state in an environment object lets every NavigationStack in
/// the four tabs subscribe to the same visibility, and lets every sub-page
/// (no matter how deep) toggle it without prop-drilling Bindings.
@MainActor
final class TabBarVisibilityController: ObservableObject {
    @Published var visibility: Visibility = .visible

    /// Reference count of pushed sub-pages currently asking the tab bar to
    /// stay hidden. Multiple-level pushes (e.g. detail → another detail) keep
    /// the tab bar hidden until the whole chain pops.
    private var hiddenRequesters: Int = 0

    func acquireHidden(animated: Bool = false) {
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
    /// Sub-page convenience: bind `.onAppear` / `.onDisappear` to the shared
    /// `TabBarVisibilityController` so the tab bar slides out on push and
    /// slides back in on pop.
    ///
    /// onAppear sets hidden WITHOUT animation — SwiftUI's NavigationStack
    /// push transition is already running, so the tab bar disappearance
    /// rides along with it (perceived as a slide). onDisappear (pop) wraps
    /// the visible flip in `withAnimation` so the bar slides back in
    /// smoothly even though pop has already finished animating the view.
    @MainActor
    func hidesTabBarOnAppear() -> some View {
        modifier(HidesTabBarOnAppearModifier())
    }
}

private struct HidesTabBarOnAppearModifier: ViewModifier {
    @EnvironmentObject private var controller: TabBarVisibilityController

    func body(content: Content) -> some View {
        content
            // Animate BOTH directions. onAppear used to be unanimated under
            // the assumption that NavigationStack's own push transition
            // would carry the tab bar slide for free, but in practice that
            // didn't happen (tab bar would just snap out instantly while
            // the rest of the push animated). Animating the visibility
            // change explicitly produces a slide that runs alongside push.
            .onAppear { controller.acquireHidden(animated: true) }
            .onDisappear { controller.release(animated: true) }
    }
}

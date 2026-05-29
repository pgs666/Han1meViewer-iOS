import SwiftUI
import UIKit

/// Hidden tag-along view that walks up to the enclosing UINavigationController
/// and forces its `interactivePopGestureRecognizer` back on. SwiftUI's
/// `.toolbar(.hidden, for: .navigationBar)` modifier turns the nav bar off
/// AND incidentally disables the edge swipe-back gesture on the underlying
/// UINavigationController. Re-enabling it manually keeps the iOS-standard
/// edge-swipe to pop while the nav bar stays visually invisible.
private struct InteractivePopEnabler: UIViewControllerRepresentable {
    typealias UIViewControllerType = PopEnablerViewController

    func makeUIViewController(context: Context) -> PopEnablerViewController {
        PopEnablerViewController()
    }

    func updateUIViewController(_ uiViewController: PopEnablerViewController, context: Context) {}
}

final class PopEnablerViewController: UIViewController {
    // Retained so the recognizer's weak `delegate` doesn't dangle.
    private let popDelegate = PopGestureDelegate()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyOnce()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyOnce()
    }

    private func applyOnce() {
        guard let nav = navigationControllerInChain else { return }
        popDelegate.navigationController = nav
        nav.interactivePopGestureRecognizer?.isEnabled = true
        // Install our own delegate (NOT nil). nil falls back to a policy
        // where the edge-swipe refuses to recognise simultaneously with
        // any other gesture — so the video player's
        // DragGesture(minimumDistance: 0), which claims the touch the
        // instant a finger lands, CANCELS the edge swipe. Our delegate
        // returns true from shouldRecognizeSimultaneouslyWith so the
        // edge-pop and the SwiftUI drag can both proceed; the player's
        // left/right deadzone then makes the drag a no-op at the edge,
        // leaving the pop to drive the back navigation.
        nav.interactivePopGestureRecognizer?.delegate = popDelegate
    }

    private var navigationControllerInChain: UINavigationController? {
        var node: UIViewController? = parent ?? self
        while let v = node {
            if let nav = v as? UINavigationController { return nav }
            if let nav = v.navigationController { return nav }
            node = v.parent
        }
        return nil
    }
}

/// Delegate that keeps the edge swipe-back alive even when it overlaps a
/// SwiftUI gesture (e.g. the video player's full-area drag).
final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    private var canPop: Bool { (navigationController?.viewControllers.count ?? 0) > 1 }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        canPop
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        canPop
    }
}

extension View {
    /// Restores the interactive (edge-swipe) pop gesture on the enclosing
    /// UINavigationController even after the navigation bar has been
    /// hidden via SwiftUI `.toolbar(.hidden, for: .navigationBar)`.
    func enableInteractivePopOnHiddenNavBar() -> some View {
        background(InteractivePopEnabler())
    }
}

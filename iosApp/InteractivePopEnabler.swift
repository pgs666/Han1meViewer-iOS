import SwiftUI
import UIKit

/// Hidden tag-along view that walks up to the enclosing UINavigationController
/// and forces its `interactivePopGestureRecognizer` back on. SwiftUI's
/// `.toolbar(.hidden, for: .navigationBar)` modifier turns the nav bar off
/// AND incidentally disables the edge swipe-back gesture on the underlying
/// UINavigationController. Re-enabling it manually keeps the iOS-standard
/// edge-swipe to pop while the nav bar stays visually invisible.
private struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Coordinator { Coordinator() }
    func updateUIViewController(_ uiViewController: Coordinator, context: Context) {}

    final class Coordinator: UIViewController {
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
            // Re-enable. We intentionally null out the delegate so UIKit
            // falls back to its default permissive policy (allow pop
            // whenever the stack has > 1 vc), instead of whatever
            // delegate SwiftUI installed that's currently refusing.
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = nil
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
}

extension View {
    /// Restores the interactive (edge-swipe) pop gesture on the enclosing
    /// UINavigationController even after the navigation bar has been
    /// hidden via SwiftUI `.toolbar(.hidden, for: .navigationBar)`.
    func enableInteractivePopOnHiddenNavBar() -> some View {
        background(InteractivePopEnabler())
    }
}

import SwiftUI
import UIKit

/// Hidden helper that, when its `signal` token changes, walks up to the
/// nearest UINavigationController and calls `popToRootViewController`. Used
/// to give SwiftUI tabs the iOS-standard "tap a tab to return to its root"
/// behaviour without throwing away the tab's root view itself (an `.id()`
/// reset would tear down the whole subtree, including the root, which the
/// user did NOT want).
struct PopToRootOnSignal: UIViewControllerRepresentable {
    let signal: UUID
    typealias UIViewControllerType = PopToRootViewController

    func makeUIViewController(context: Context) -> PopToRootViewController {
        let vc = PopToRootViewController()
        vc.lastSignal = signal
        return vc
    }

    func updateUIViewController(_ uiViewController: PopToRootViewController, context: Context) {
        guard uiViewController.lastSignal != signal else { return }
        uiViewController.lastSignal = signal
        // popToRoot must run after the current SwiftUI update cycle so the
        // navigation stack is in a stable state.
        DispatchQueue.main.async {
            uiViewController.popNavigationToRoot()
        }
    }
}

final class PopToRootViewController: UIViewController {
    var lastSignal: UUID?

    func popNavigationToRoot() {
        guard let nav = navigationControllerInChain else { return }
        guard nav.viewControllers.count > 1 else { return }
        nav.popToRootViewController(animated: true)
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

extension View {
    /// Whenever `signal` changes, asks the enclosing UINavigationController
    /// to pop back to its root view controller. The root view itself is NOT
    /// rebuilt — only pushed sub-pages are popped (and thus deinit'd).
    func popsToRootWhen(signal: UUID) -> some View {
        background(PopToRootOnSignal(signal: signal))
    }
}

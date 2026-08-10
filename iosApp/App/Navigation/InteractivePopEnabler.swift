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

    var disabled: Bool

    func makeUIViewController(context: Context) -> PopEnablerViewController {
        PopEnablerViewController()
    }

    func updateUIViewController(_ uiViewController: PopEnablerViewController, context: Context) {
        uiViewController.popDelegate.disabled = disabled
    }
}

final class PopEnablerViewController: UIViewController {
    // Retained so the recognizer's weak `delegate` doesn't dangle.
    let popDelegate = PopGestureDelegate()

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
        // Install our own delegate (NOT nil). It allows the player's
        // full-area SwiftUI gesture to coexist with edge-pop, but keeps
        // UIScrollView pan gestures exclusive. The latter is important for
        // page-style TabView, whose underlying paging scroll view would
        // otherwise move at the same time as the navigation transition.
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
    /// When true (e.g. the player is fullscreen), the edge swipe-back is
    /// suppressed so horizontal swipes drive seek instead of popping.
    var disabled = false

    private var canPop: Bool { !disabled && (navigationController?.viewControllers.count ?? 0) > 1 }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        canPop
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard canPop else { return false }

        // UIKit's default gesture-arbitration model is exclusive. Preserve
        // that default for every UIScrollView pan gesture, including the
        // private paging scroll view used by SwiftUI's page-style TabView.
        // The interactive-pop recognizer can then own a left-edge drag
        // instead of the pager responding alongside it.
        if isScrollViewPan(otherGestureRecognizer) {
            return false
        }

        // The custom player DragGesture still needs simultaneous recognition:
        // it claims touches immediately, but deliberately does no work inside
        // its edge dead zone so interactive pop can drive navigation.
        return true
    }

    private func isScrollViewPan(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let scrollView = gestureRecognizer.view as? UIScrollView else {
            return false
        }
        return gestureRecognizer === scrollView.panGestureRecognizer
    }
}

/// Connects SwiftUI's page-style TabView paging recognizer to UIKit's
/// interactive-pop recognizer with the correct failure direction:
/// pager.pan requires edge-pop to fail.
struct PagerEdgePopPriorityBridge: UIViewRepresentable {
    func makeUIView(context: Context) -> CoordinatorView {
        CoordinatorView()
    }

    func updateUIView(_ uiView: CoordinatorView, context: Context) {
        uiView.scheduleConfiguration()
    }

    final class CoordinatorView: UIView {
        private var isConfigurationScheduled = false
        private var remainingRetries = 12
        private var configuredPagingRecognizers = Set<ObjectIdentifier>()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            remainingRetries = 12
            scheduleConfiguration()
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            remainingRetries = 12
            scheduleConfiguration()
        }

        func scheduleConfiguration() {
            guard !isConfigurationScheduled else { return }
            isConfigurationScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isConfigurationScheduled = false
                if !self.configureFailureRequirement(), self.remainingRetries > 0 {
                    self.remainingRetries -= 1
                    self.scheduleConfiguration()
                }
            }
        }

        private func configureFailureRequirement() -> Bool {
            guard let popGesture = enclosingNavigationController?
                .interactivePopGestureRecognizer else {
                return false
            }

            var configuredAny = false
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView, scrollView.isPagingEnabled {
                    let panGesture = scrollView.panGestureRecognizer
                    let identifier = ObjectIdentifier(panGesture)
                    if !configuredPagingRecognizers.contains(identifier) {
                        // Apple-supported precedence API: the pager waits for
                        // the system edge-pop recognizer to fail. This keeps
                        // normal paging away from the edge while guaranteeing
                        // that a valid back swipe wins at the left edge.
                        panGesture.require(toFail: popGesture)
                        configuredPagingRecognizers.insert(identifier)
                    }
                    configuredAny = true
                }
                ancestor = view.superview
            }
            return configuredAny
        }

        private var enclosingNavigationController: UINavigationController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let navigationController = current as? UINavigationController {
                    return navigationController
                }
                if let viewController = current as? UIViewController,
                   let navigationController = viewController.navigationController {
                    return navigationController
                }
                responder = current.next
            }
            return nil
        }
    }
}

extension View {
    /// Restores the interactive (edge-swipe) pop gesture on the enclosing
    /// UINavigationController even after the navigation bar has been
    /// hidden via SwiftUI `.toolbar(.hidden, for: .navigationBar)`.
    func enableInteractivePopOnHiddenNavBar(disabled: Bool = false) -> some View {
        background(InteractivePopEnabler(disabled: disabled))
    }
}

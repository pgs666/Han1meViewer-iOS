import UIKit

enum VideoFullscreenOrientation {
    case portrait
    case landscape

    var mask: UIInterfaceOrientationMask {
        switch self {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscape
        }
    }

    var interfaceOrientation: UIInterfaceOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscapeRight
        }
    }
}

final class AppOrientationController {
    static let shared = AppOrientationController()

    private(set) var supportedOrientations: UIInterfaceOrientationMask = AppOrientationController.defaultMask
    private var orientationBeforeFullscreen: UIInterfaceOrientation?
    private var supportedOrientationsBeforeFullscreen: UIInterfaceOrientationMask?

    private init() {}

    static var defaultMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
    }

    func lockForFullscreen(to orientation: VideoFullscreenOrientation) {
        if orientationBeforeFullscreen == nil {
            orientationBeforeFullscreen = currentInterfaceOrientation
            supportedOrientationsBeforeFullscreen = supportedOrientations
        }
        supportedOrientations = orientation.mask
        request(interfaceOrientation: orientation.interfaceOrientation, mask: orientation.mask)
    }

    func unlockAfterFullscreen() {
        let previousMask = supportedOrientationsBeforeFullscreen ?? Self.defaultMask
        let previousOrientation = orientationBeforeFullscreen?.normalized(for: previousMask) ?? previousMask.preferredOrientation
        orientationBeforeFullscreen = nil
        supportedOrientationsBeforeFullscreen = nil
        supportedOrientations = previousMask
        request(interfaceOrientation: previousOrientation, mask: previousMask)
    }

    func enforceCurrentOrientationMask() {
        let orientation = currentInterfaceOrientation?.normalized(for: supportedOrientations)
            ?? supportedOrientations.preferredOrientation
        request(interfaceOrientation: orientation, mask: supportedOrientations)
    }

    private var currentInterfaceOrientation: UIInterfaceOrientation? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .interfaceOrientation
    }

    private func request(interfaceOrientation: UIInterfaceOrientation, mask: UIInterfaceOrientationMask) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.request(interfaceOrientation: interfaceOrientation, mask: mask)
            }
            return
        }

        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        if #available(iOS 16.0, *), let windowScene {
            windowScene.windows
                .first { $0.isKeyWindow }?
                .rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in
                UIDevice.current.setValue(interfaceOrientation.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
            UIDevice.current.setValue(interfaceOrientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        } else {
            UIDevice.current.setValue(interfaceOrientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}

private extension UIInterfaceOrientation {
    func normalized(for mask: UIInterfaceOrientationMask) -> UIInterfaceOrientation {
        if mask.contains(self.mask) {
            return self
        }
        return mask.preferredOrientation
    }

    var mask: UIInterfaceOrientationMask {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .portrait
        }
    }
}

private extension UIInterfaceOrientationMask {
    var preferredOrientation: UIInterfaceOrientation {
        if contains(.portrait) {
            return .portrait
        }
        if contains(.landscapeRight) {
            return .landscapeRight
        }
        if contains(.landscapeLeft) {
            return .landscapeLeft
        }
        if contains(.portraitUpsideDown) {
            return .portraitUpsideDown
        }
        return .portrait
    }
}

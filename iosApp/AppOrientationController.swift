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

    private(set) var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown
    private var orientationBeforeFullscreen: UIInterfaceOrientation?
    private var supportedOrientationsBeforeFullscreen: UIInterfaceOrientationMask?

    private init() {}

    func lockForFullscreen(to orientation: VideoFullscreenOrientation) {
        if orientationBeforeFullscreen == nil {
            orientationBeforeFullscreen = currentInterfaceOrientation
            supportedOrientationsBeforeFullscreen = supportedOrientations
        }
        supportedOrientations = orientation.mask
        request(interfaceOrientation: orientation.interfaceOrientation, mask: orientation.mask)
    }

    func unlockAfterFullscreen() {
        let previousOrientation = orientationBeforeFullscreen?.normalizedForPhone ?? .portrait
        let previousMask = supportedOrientationsBeforeFullscreen ?? .allButUpsideDown
        orientationBeforeFullscreen = nil
        supportedOrientationsBeforeFullscreen = nil
        supportedOrientations = previousMask
        request(interfaceOrientation: previousOrientation, mask: previousMask)
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

        if #available(iOS 16.0, *),
           let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        } else {
            UIDevice.current.setValue(interfaceOrientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}

private extension UIInterfaceOrientation {
    var normalizedForPhone: UIInterfaceOrientation {
        self == .portraitUpsideDown ? .portrait : self
    }
}

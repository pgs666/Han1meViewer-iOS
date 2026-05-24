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

    private init() {}

    func lock(to orientation: VideoFullscreenOrientation) {
        supportedOrientations = orientation.mask
        request(interfaceOrientation: orientation.interfaceOrientation, mask: orientation.mask)
    }

    func unlockAfterFullscreen() {
        supportedOrientations = .allButUpsideDown
        request(interfaceOrientation: .portrait, mask: .allButUpsideDown)
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

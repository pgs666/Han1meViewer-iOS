import UIKit
import Nuke

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientationController.shared.supportedOrientations
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureImagePipeline()
        return true
    }

    private func configureImagePipeline() {
        var config = ImagePipeline.Configuration()
        config.isProgressiveDecodingEnabled = false
        config.imageCache = ImageCache(costLimit: 100 * 1024 * 1024)
        ImagePipeline.shared = ImagePipeline(configuration: config)
    }
}

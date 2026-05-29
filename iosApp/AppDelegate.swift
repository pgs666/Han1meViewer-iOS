import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientationController.shared.supportedOrientations
    }

    /// Called when the app is relaunched in the background to finish
    /// handling completed background URLSession transfers. We stash the
    /// completion handler on DownloadManager, which invokes it from
    /// urlSessionDidFinishEvents(forBackgroundURLSession:) once all
    /// events for the matching session have been delivered.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            DownloadManager.shared.backgroundCompletionHandler = completionHandler
        }
    }
}

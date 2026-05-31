import SwiftUI

/// A button that opens the Cloudflare verification WebView, shown only when
/// the surrounding error message indicates a Cloudflare challenge.
///
/// CloudflareChallengePresenter (root-level) auto-opens the WebView the
/// first time a CF error surfaces — but if the user dismissed the cover
/// without solving the challenge, or re-enters a failed-state view after
/// the cover was already dismissed, there was no way to re-trigger it.
/// This button fills that gap as a manual escape hatch right next to the
/// usual 重试 button.
struct CloudflareVerifyButton: View {
    let errorMessage: String

    var body: some View {
        if Self.indicatesCloudflare(errorMessage) {
            Button {
                CloudflareChallengeCenter.requestChallenge()
            } label: {
                Label("完成浏览器验证", systemImage: "shield")
            }
            .buttonStyle(.bordered)
        }
    }

    /// Match against the live localized value of the `error.cloudflare`
    /// key, so the check survives translation updates without a hard-coded
    /// substring list.
    static func indicatesCloudflare(_ message: String) -> Bool {
        message == String(localized: "error.cloudflare")
    }
}

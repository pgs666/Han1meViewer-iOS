import SwiftUI
import WebKit
import Han1meShared

struct CloudflareChallengePresenter: ViewModifier {
    let cloudflareFeature: CloudflareFeature

    @State private var challengeRequest: CloudflareChallengeRequest?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: CloudflareChallengeCenter.requestNotification)) { notification in
                if let url = notification.userInfo?[CloudflareChallengeCenter.urlKey] as? URL {
                    challengeRequest = CloudflareChallengeRequest(url: url)
                } else if let fallbackURL = URL(string: AppDomain.currentHomeURL) {
                    challengeRequest = CloudflareChallengeRequest(url: fallbackURL)
                }
            }
            .fullScreenCover(item: $challengeRequest) { request in
                CloudflareChallengeView(
                    url: request.url,
                    cloudflareFeature: cloudflareFeature,
                    onResolved: {
                        challengeRequest = nil
                    },
                    onCancelled: {
                        challengeRequest = nil
                    }
                )
            }
    }
}

private struct CloudflareChallengeRequest: Identifiable {
    let url: URL

    var id: String { url.absoluteString }
}

private struct CloudflareChallengeView: View {
    let url: URL
    let cloudflareFeature: CloudflareFeature
    let onResolved: () -> Void
    let onCancelled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status: ChallengeStatus = .loading

    var body: some View {
        CompatibleNavigationStack {
            VStack(spacing: 0) {
                CloudflareStatusBar(status: status)

                CloudflareWebView(
                    url: url,
                    cloudflareFeature: cloudflareFeature,
                    status: $status,
                    onResolved: {
                        // Signal the shared layer that the challenge is resolved
                        CloudflareRetryCenter.signalResolved()
                        onResolved()
                        dismiss()
                    }
                )
            }
            .navigationTitle("Cloudflare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        if status != .resolved {
                            CloudflareRetryCenter.signalFailed(
                                reason: String(localized: "Cloudflare 验证已取消")
                            )
                            onCancelled()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum ChallengeStatus: Equatable {
    case loading
    case waiting
    case importing
    case resolved
    case failed(String)
}

private struct CloudflareStatusBar: View {
    let status: ChallengeStatus

    var body: some View {
        HStack(spacing: 8) {
            switch status {
            case .loading:
                ProgressView()
                Text("正在打开验证页面")
            case .waiting:
                Label("请在网页中完成验证", systemImage: "shield")
            case .importing:
                ProgressView()
                Text("正在同步 Cloudflare Cookie")
            case .resolved:
                Label("Cloudflare 验证已同步", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
}

private struct CloudflareWebView: UIViewRepresentable {
    let url: URL
    let cloudflareFeature: CloudflareFeature
    @Binding var status: ChallengeStatus
    let onResolved: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            cloudflareFeature: cloudflareFeature,
            challengeURL: url,
            status: $status,
            onResolved: onResolved
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        configuration.websiteDataStore.httpCookieStore.add(context.coordinator)

        context.coordinator.prepareAndLoad(url: url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
        webView.navigationDelegate = nil
        coordinator.detachWebView()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        private let cloudflareFeature: CloudflareFeature
        private let challengeHost: String
        private let status: Binding<ChallengeStatus>
        private let onResolved: () -> Void
        private weak var webView: WKWebView?

        private var isImporting = false
        private var didResolve = false
        private let importStateQueue = DispatchQueue(label: "com.han1me.cf-import-state")
        private var pendingCookiesChangedWorkItem: DispatchWorkItem?
        private var baselineClearanceValue: String?
        private var hasFinishedMainFrame = false
        private var mainFrameWasChallenge = true

        init(cloudflareFeature: CloudflareFeature, challengeURL: URL, status: Binding<ChallengeStatus>, onResolved: @escaping () -> Void) {
            self.cloudflareFeature = cloudflareFeature
            self.challengeHost = challengeURL.host?.lowercased() ?? ""
            self.status = status
            self.onResolved = onResolved
        }

        func prepareAndLoad(url: URL, in webView: WKWebView) {
            self.webView = webView
            status.wrappedValue = .loading
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self, weak webView] cookies in
                guard let self, let webView, !self.isResolved else { return }
                self.baselineClearanceValue = self.clearanceCookie(in: cookies)?.value
                webView.load(URLRequest(url: url))
            }
        }

        func detachWebView() {
            pendingCookiesChangedWorkItem?.cancel()
            pendingCookiesChangedWorkItem = nil
            webView = nil
        }

        // MARK: - WKHTTPCookieStoreObserver

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            guard !isResolved else { return }

            pendingCookiesChangedWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView, !self.isResolved else { return }
                self.evaluateChallengeCompletion(in: webView)
            }
            pendingCookiesChangedWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            hasFinishedMainFrame = false
            mainFrameWasChallenge = true
            if status.wrappedValue != .importing {
                status.wrappedValue = .loading
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.isForMainFrame,
               let response = navigationResponse.response as? HTTPURLResponse {
                mainFrameWasChallenge = response.allHeaderFields.contains { key, value in
                    String(describing: key).lowercased() == "cf-mitigated" &&
                        String(describing: value).lowercased() == "challenge"
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !isResolved else { return }
            hasFinishedMainFrame = true
            if status.wrappedValue != .importing {
                status.wrappedValue = .waiting
            }
            evaluateChallengeCompletion(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            status.wrappedValue = .failed(ErrorMessage.userFriendly(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            status.wrappedValue = .failed(ErrorMessage.userFriendly(error))
        }

        private func evaluateChallengeCompletion(in webView: WKWebView) {
            guard hasFinishedMainFrame, !isResolved else { return }

            let checkScript = """
            (() => {
                if (document.readyState !== 'complete') return false;
                const selectors = [
                    '#challenge-form',
                    '#challenge-stage',
                    '#challenge-running',
                    '#challenge-success-text',
                    '#challenge-error-text',
                    'iframe[src*="challenges.cloudflare.com"]'
                ];
                return !selectors.some(selector => document.querySelector(selector));
            })();
            """
            webView.evaluateJavaScript(checkScript) { [weak self, weak webView] result, _ in
                guard let self, let webView, !self.isResolved else { return }
                guard (result as? Bool) == true else {
                    if self.status.wrappedValue != .importing {
                        self.status.wrappedValue = .waiting
                    }
                    return
                }
                self.importClearanceCookies(from: webView)
            }
        }

        private func importClearanceCookies(from webView: WKWebView) {
            guard tryBeginImport() else {
                return
            }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.isResolved else {
                    return
                }

                let challengeCookies = cookies.filter { cookie in
                    let cookieDomain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    return !self.challengeHost.isEmpty &&
                        (cookieDomain == self.challengeHost || self.challengeHost.hasSuffix(".\(cookieDomain)"))
                }

                guard let clearanceCookie = self.clearanceCookie(in: challengeCookies) else {
                    self.finishImport()
                    return
                }

                // A persisted clearance cookie may be the same stale value that
                // caused the original request to be challenged. Accept it only
                // after a non-challenge main-frame response, or when Cloudflare
                // replaced it while the user completed this challenge.
                let clearanceWasUpdated = self.baselineClearanceValue != clearanceCookie.value
                guard clearanceWasUpdated || !self.mainFrameWasChallenge else {
                    self.finishImport()
                    self.status.wrappedValue = .waiting
                    return
                }

                let cookieJson = Self.encodeCookiesForImport(challengeCookies)

                guard let cookieJson, !cookieJson.isEmpty else {
                    self.finishImport()
                    return
                }

                Task { @MainActor in
                    self.status.wrappedValue = .importing
                    do {
                        let snapshot = try await self.cloudflareFeature.importChallengeCookiesJson(
                            cookieJson: cookieJson,
                            fallbackDomain: self.challengeHost
                        )
                        self.finishImport()
                        if snapshot.hasClearance {
                            self.markResolved()
                            self.status.wrappedValue = .resolved
                            self.onResolved()
                        } else {
                            self.status.wrappedValue = .waiting
                        }
                    } catch {
                        self.finishImport()
                        self.status.wrappedValue = .failed(ErrorMessage.userFriendly(error))
                    }
                }
            }
        }

        private func clearanceCookie(in cookies: [HTTPCookie]) -> HTTPCookie? {
            cookies.first { cookie in
                guard cookie.name == "cf_clearance" else { return false }
                let cookieDomain = cookie.domain
                    .lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                let matchesHost = !challengeHost.isEmpty &&
                    (cookieDomain == challengeHost || challengeHost.hasSuffix(".\(cookieDomain)"))
                let hasNotExpired = cookie.expiresDate.map { $0 > Date() } ?? true
                return matchesHost && hasNotExpired && !cookie.value.isEmpty
            }
        }

        fileprivate static func encodeCookiesForImport(_ cookies: [HTTPCookie]) -> String? {
            let payload: [[String: Any]] = cookies.compactMap { cookie in
                guard !cookie.name.isEmpty, !cookie.value.isEmpty else {
                    return nil
                }
                var entry: [String: Any] = [
                    "name": cookie.name,
                    "value": cookie.value,
                ]
                if !cookie.domain.isEmpty {
                    entry["domain"] = cookie.domain
                }
                if !cookie.path.isEmpty {
                    entry["path"] = cookie.path
                }
                if let expiresDate = cookie.expiresDate {
                    entry["expiresAtEpochMillis"] = Int64(expiresDate.timeIntervalSince1970 * 1000)
                }
                entry["secure"] = cookie.isSecure
                entry["httpOnly"] = cookie.isHTTPOnly
                return entry
            }

            guard !payload.isEmpty, let data = try? JSONSerialization.data(withJSONObject: payload) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }

        private var isResolved: Bool {
            importStateQueue.sync {
                didResolve
            }
        }

        private func tryBeginImport() -> Bool {
            importStateQueue.sync {
                guard !didResolve, !isImporting else {
                    return false
                }
                isImporting = true
                return true
            }
        }

        private func finishImport() {
            importStateQueue.sync {
                isImporting = false
            }
        }

        private func markResolved() {
            importStateQueue.sync {
                didResolve = true
                isImporting = false
            }
        }
    }
}

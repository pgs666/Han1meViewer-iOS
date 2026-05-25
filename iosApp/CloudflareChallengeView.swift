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
                } else {
                    challengeRequest = CloudflareChallengeRequest(url: URL(string: "https://hanime1.me")!)
                }
            }
            .sheet(item: $challengeRequest) { request in
                CloudflareChallengeView(
                    url: request.url,
                    cloudflareFeature: cloudflareFeature,
                    onResolved: {
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
            status: $status,
            onResolved: onResolved
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        configuration.websiteDataStore.httpCookieStore.add(context.coordinator)

        context.coordinator.load(url: url, in: webView)
        context.coordinator.importClearanceCookies(from: webView)
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
        private let onResolved: () -> Void
        private weak var webView: WKWebView?
        private let importStateQueue = DispatchQueue(label: "app.han1me.cloudflare.cookie-import")
        private var didResolve = false
        private var isImporting = false

        @Binding private var status: ChallengeStatus

        init(
            cloudflareFeature: CloudflareFeature,
            status: Binding<ChallengeStatus>,
            onResolved: @escaping () -> Void
        ) {
            self.cloudflareFeature = cloudflareFeature
            self.onResolved = onResolved
            _status = status
        }

        func load(url: URL, in webView: WKWebView) {
            self.webView = webView
            status = .loading
            webView.load(URLRequest(url: url))
        }

        func detachWebView() {
            webView = nil
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            guard let webView else {
                return
            }
            importClearanceCookies(from: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !isResolved {
                status = .waiting
                importClearanceCookies(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            status = .failed(ErrorMessage.userFriendly(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            status = .failed(ErrorMessage.userFriendly(error))
        }

        func importClearanceCookies(from webView: WKWebView) {
            guard tryBeginImport() else {
                return
            }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.isResolved else {
                    return
                }

                let hanimeCookies = cookies.filter { cookie in
                    cookie.domain.contains("hanime1.me")
                }

                guard hanimeCookies.contains(where: { $0.name == "cf_clearance" }) else {
                    self.finishImport()
                    return
                }

                let cookieHeader = hanimeCookies
                    .map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")

                guard !cookieHeader.isEmpty else {
                    self.finishImport()
                    return
                }

                Task { @MainActor in
                    self.status = .importing
                    do {
                        let snapshot = try await self.cloudflareFeature.importChallengeCookieHeader(
                            cookieHeader: cookieHeader,
                            domain: "hanime1.me"
                        )
                        self.finishImport()
                        if snapshot.hasClearance {
                            self.markResolved()
                            self.status = .resolved
                            self.onResolved()
                        } else {
                            self.status = .waiting
                        }
                    } catch {
                        self.finishImport()
                        self.status = .failed(ErrorMessage.userFriendly(error))
                    }
                }
            }
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

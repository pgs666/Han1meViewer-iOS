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

    @Environment(\.presentationMode) private var presentationMode
    @State private var status: ChallengeStatus = .loading

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CloudflareStatusBar(status: status)

                CloudflareWebView(
                    url: url,
                    cloudflareFeature: cloudflareFeature,
                    status: $status,
                    onResolved: {
                        onResolved()
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .navigationTitle("Cloudflare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
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
                    .foregroundColor(.green)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
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

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        private let cloudflareFeature: CloudflareFeature
        private let onResolved: () -> Void
        private weak var webView: WKWebView?
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

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            guard let webView else {
                return
            }
            importClearanceCookies(from: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if !didResolve {
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
            guard !didResolve, !isImporting else {
                return
            }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.didResolve, !self.isImporting else {
                    return
                }

                let hanimeCookies = cookies.filter { cookie in
                    cookie.domain.contains("hanime1.me")
                }

                guard hanimeCookies.contains(where: { $0.name == "cf_clearance" }) else {
                    return
                }

                let cookieHeader = hanimeCookies
                    .map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")

                guard !cookieHeader.isEmpty else {
                    return
                }

                self.isImporting = true
                Task { @MainActor in
                    self.status = .importing
                    do {
                        let snapshot = try await self.cloudflareFeature.importChallengeCookieHeader(
                            cookieHeader: cookieHeader,
                            domain: "hanime1.me"
                        )
                        self.isImporting = false
                        if snapshot.hasClearance {
                            self.didResolve = true
                            self.status = .resolved
                            self.onResolved()
                        } else {
                            self.status = .waiting
                        }
                    } catch {
                        self.isImporting = false
                        self.status = .failed(ErrorMessage.userFriendly(error))
                    }
                }
            }
        }
    }
}

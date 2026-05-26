import SwiftUI
import WebKit
import Han1meShared

struct LoginView: View {
    let webLoginFeature: WebLoginFeature
    let onLoginSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status: LoginStatus = .idle
    @State private var reloadToken = UUID()

    var body: some View {
        VStack(spacing: 0) {
            WebLoginStatusBar(status: status)

            WebLoginView(
                reloadToken: reloadToken,
                webLoginFeature: webLoginFeature,
                status: $status,
                onLoginSuccess: {
                    onLoginSuccess()
                    dismiss()
                }
            )
        }
        .navigationTitle("账号登录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    status = .loading
                    reloadToken = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("刷新登录页")
            }
        }
    }

    private static func encodeCookiesForImport(_ cookies: [HTTPCookie]) -> String? {
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
}

private enum LoginStatus: Equatable {
    case idle
    case loading
    case imported
    case failed(String)
}

private struct WebLoginStatusBar: View {
    let status: LoginStatus

    var body: some View {
        HStack(spacing: 8) {
            switch status {
            case .idle:
                Label("请在网页中完成登录", systemImage: "globe")
            case .loading:
                ProgressView()
                Text("正在载入登录页")
            case .imported:
                Label("已同步登录 Cookie", systemImage: "checkmark.circle.fill")
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

    private static func encodeCookiesForImport(_ cookies: [HTTPCookie]) -> String? {
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
}

private struct WebLoginView: UIViewRepresentable {
    let reloadToken: UUID
    let webLoginFeature: WebLoginFeature
    @Binding var status: LoginStatus
    let onLoginSuccess: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            webLoginFeature: webLoginFeature,
            status: $status,
            onLoginSuccess: onLoginSuccess
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.reloadToken = reloadToken
        context.coordinator.loadLoginPage(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.reloadToken != reloadToken {
            context.coordinator.reloadToken = reloadToken
            context.coordinator.loadLoginPage(in: webView)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var reloadToken: UUID?

        private let webLoginFeature: WebLoginFeature
        private let onLoginSuccess: () -> Void
        private var didCompleteLogin = false
        private var isImportingLogin = false
        @Binding private var status: LoginStatus

        init(
            webLoginFeature: WebLoginFeature,
            status: Binding<LoginStatus>,
            onLoginSuccess: @escaping () -> Void
        ) {
            self.webLoginFeature = webLoginFeature
            self.onLoginSuccess = onLoginSuccess
            _status = status
        }

        func loadLoginPage(in webView: WKWebView) {
            didCompleteLogin = false
            isImportingLogin = false
            guard let url = URL(string: "https://hanime1.me/login") else {
                status = .failed(String(localized: "登录地址无效"))
                return
            }
            status = .loading
            webView.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            status = .idle
            evaluateLoginSuccess(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            status = .failed(ErrorMessage.userFriendly(error))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            status = .failed(ErrorMessage.userFriendly(error))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        private func evaluateLoginSuccess(in webView: WKWebView) {
            guard !didCompleteLogin, !isImportingLogin else {
                return
            }

            let script = """
            (() => {
              const hrefs = Array.from(document.querySelectorAll('a[href], form[action]'))
                .map((element) => (element.getAttribute('href') || element.getAttribute('action') || '').toLowerCase());
              const text = (document.body && document.body.innerText || '').toLowerCase();
              const hasLogoutAction = hrefs.some((href) => href.includes('logout') || href.includes('signout'));
              const hasLogoutText = text.includes('登出') || text.includes('注销') || text.includes('logout') || text.includes('sign out');
              const hasUserMenu = document.querySelector('[href*="/user"], [href*="/users"], .user-avatar, .avatar, .dropdown-user') !== null;
              return hasLogoutAction || hasLogoutText || hasUserMenu;
            })();
            """

            webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
                guard let self, let webView else { return }
                guard result as? Bool == true else {
                    return
                }
                Task { @MainActor in
                    self.importConfirmedLoginCookies(from: webView)
                }
            }
        }

        private func importConfirmedLoginCookies(from webView: WKWebView) {
            guard !didCompleteLogin, !isImportingLogin else {
                return
            }
            isImportingLogin = true

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self else { return }
                let hanimeCookies = cookies.filter { cookie in
                    cookie.domain.contains("hanime1.me")
                }

                let cookieJson = LoginView.encodeCookiesForImport(hanimeCookies)

                guard let cookieJson, !cookieJson.isEmpty else {
                    Task { @MainActor in
                        self.isImportingLogin = false
                    }
                    return
                }

                Task { @MainActor in
                    guard !self.didCompleteLogin else {
                        self.isImportingLogin = false
                        return
                    }
                    do {
                        let snapshot = try await self.webLoginFeature.importConfirmedLoginCookiesJson(
                            cookieJson: cookieJson,
                            fallbackDomain: "hanime1.me"
                        )
                        if snapshot.isLoggedIn {
                            self.status = .imported
                            self.didCompleteLogin = true
                            self.onLoginSuccess()
                        } else {
                            self.isImportingLogin = false
                        }
                    } catch {
                        self.isImportingLogin = false
                        self.status = .failed(ErrorMessage.userFriendly(error))
                    }
                }
            }
        }
    }

    private static func encodeCookiesForImport(_ cookies: [HTTPCookie]) -> String? {
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
}

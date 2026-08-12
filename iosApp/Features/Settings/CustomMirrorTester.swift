import Foundation
import Han1meShared

struct CustomMirrorTestResult {
    let succeeded: Bool
    let message: String
}

enum CustomMirrorTester {
    static func test(homeURL: String, appendPath: Bool) async -> CustomMirrorTestResult {
        guard let homeRequestURL = URL(string: homeURL),
              let apiBaseURL = AppDomain.apiBaseURL(homeURL: homeURL, appendPath: appendPath),
              let searchURL = AppDomain.appending("search", to: apiBaseURL) else {
            return .init(succeeded: false, message: String(localized: "请输入有效且直达首页的 HTTPS 地址。"))
        }

        do {
            let (homeData, homeResponse) = try await request(homeRequestURL)
            guard (200..<300).contains(homeResponse.statusCode) else {
                return .init(
                    succeeded: false,
                    message: String(
                        format: String(localized: "测试失败：HTTP %d\n首页：%@"),
                        homeResponse.statusCode,
                        homeResponse.url?.absoluteString ?? homeURL
                    )
                )
            }

            let html = String(decoding: homeData, as: UTF8.self)
            if let parseError = KsoupHtmlParser(baseUrl: homeURL).validateHome(html: html) {
                return .init(
                    succeeded: false,
                    message: String(
                        format: String(localized: "已连接，但首页结构解析失败\n首页：%@\n原因：%@"),
                        homeResponse.url?.absoluteString ?? homeURL,
                        parseError
                    )
                )
            }

            do {
                let (_, searchResponse) = try await request(searchURL)
                guard (200..<300).contains(searchResponse.statusCode) else {
                    return partialSuccess(
                        homeURL: homeResponse.url?.absoluteString ?? homeURL,
                        apiBaseURL: apiBaseURL,
                        reason: "HTTP \(searchResponse.statusCode)"
                    )
                }
            } catch {
                return partialSuccess(
                    homeURL: homeResponse.url?.absoluteString ?? homeURL,
                    apiBaseURL: apiBaseURL,
                    reason: ErrorMessage.userFriendly(error)
                )
            }

            return .init(
                succeeded: true,
                message: String(
                    format: String(localized: "测试成功\n首页：%@\n其他接口测试：%@search"),
                    homeResponse.url?.absoluteString ?? homeURL,
                    apiBaseURL.hasSuffix("/") ? apiBaseURL : "\(apiBaseURL)/"
                )
            )
        } catch {
            return .init(
                succeeded: false,
                message: String(
                    format: String(localized: "测试失败：%@"),
                    ErrorMessage.userFriendly(error)
                )
            )
        }
    }

    private static func request(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }

    private static func partialSuccess(
        homeURL: String,
        apiBaseURL: String,
        reason: String
    ) -> CustomMirrorTestResult {
        .init(
            succeeded: false,
            message: String(
                format: String(localized: "首页测试成功，但其他接口测试失败\n首页：%@\n其他接口基址：%@\n原因：%@"),
                homeURL,
                apiBaseURL,
                reason
            )
        )
    }
}

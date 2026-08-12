import Foundation
import SwiftUI

/// Available site domains, mirroring the Android client's domain switch
/// (HanimeConstants.HANIME_URL). The selected domain is persisted under
/// the shared `domain_name` preference key (same key the KMP
/// PreferencesStore uses). Because every Ktor repository captures its
/// baseUrl at construction time inside SharedAppEnvironment, switching
/// the domain takes effect on the next app launch (the settings UI tells
/// the user to restart) — matching the Android behaviour.
enum AppDomain {
    static let preferenceKey = "domain_name"

    /// (host shown verbatim, base URL, localized suffix key). Base URLs
    /// have NO trailing slash to match SharedAppEnvironment's expectation.
    static let options: [(host: String, url: String, suffix: LocalizedStringKey)] = [
        ("hanime1.me", "https://hanime1.me", "默认"),
        ("hanime1.com", "https://hanime1.com", "备用"),
        ("hanimeone.me", "https://hanimeone.me", "备用"),
        ("javchu.com", "https://javchu.com", "AV"),
    ]

    static let defaultBaseURL = "https://hanime1.me"

    /// Reads and normalises either a predefined domain or a custom HTTPS
    /// origin. Invalid legacy values fall back to the default domain.
    static var currentBaseURL: String {
        let stored = UserDefaults.standard.string(forKey: preferenceKey)
        guard let stored, !stored.isEmpty else { return defaultBaseURL }
        return normalizedBaseURL(from: stored) ?? defaultBaseURL
    }

    static var currentHost: String {
        URLComponents(string: currentBaseURL)?.host?.lowercased() ?? "hanime1.me"
    }

    static var isAVSite: Bool {
        currentHost == "javchu.com" || currentHost.hasSuffix(".javchu.com")
    }

    static func cookieDomain(_ cookieDomain: String, matches host: String) -> Bool {
        let normalizedCookieDomain = cookieDomain
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let normalizedHost = host
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return !normalizedCookieDomain.isEmpty &&
            (normalizedHost == normalizedCookieDomain || normalizedHost.hasSuffix(".\(normalizedCookieDomain)"))
    }

    static func setBaseURL(_ url: String) {
        guard let normalized = normalizedBaseURL(from: url) else { return }
        UserDefaults.standard.set(normalized, forKey: preferenceKey)
    }

    static func isPreset(_ url: String) -> Bool {
        options.contains { $0.url == url }
    }

    static func displayHost(for url: String) -> String {
        URLComponents(string: url)?.host ?? url
    }

    /// Accept a HTTPS origin only. Repositories append their own paths to
    /// this value, so a mirror base URL cannot contain a path, query, or
    /// fragment. A missing scheme is treated as HTTPS for easier entry.
    static func normalizedBaseURL(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            return nil
        }

        components.scheme = "https"
        components.host = host.lowercased()
        components.path = ""
        return components.url?.absoluteString
    }
}

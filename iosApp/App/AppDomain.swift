import Foundation
import SwiftUI

/// Site selection compatible with Android's `Preferences.baseUrl/homeUrl`.
/// Preset selection and custom-mirror configuration are stored separately so
/// disabling a custom mirror returns to the previously selected preset.
enum AppDomain {
    static let preferenceKey = "domain_name"
    static let selectedBaseURLKey = "selectedBaseUrl"
    static let useCustomMirrorKey = "use_custom_mirror_site"
    static let customMirrorSiteKey = "custom_mirror_site"
    static let appendCustomMirrorPathKey = "append_custom_mirror_path"

    static let options: [(host: String, url: String, suffix: LocalizedStringKey)] = [
        ("hanime1.me", "https://hanime1.me", "默认"),
        ("hanime1.com", "https://hanime1.com", "备用"),
        ("hanimeone.me", "https://hanimeone.me", "备用"),
        ("javchu.com", "https://javchu.com", "AV"),
    ]

    static let defaultBaseURL = "https://hanime1.me"

    static var selectedPresetURL: String {
        let defaults = UserDefaults.standard
        let selected = defaults.string(forKey: selectedBaseURLKey)
            ?? defaults.string(forKey: preferenceKey)
        return normalizedPresetURL(selected) ?? defaultBaseURL
    }

    /// Migrates the previous iOS representation, where a custom mirror was
    /// stored directly in `domain_name`, without changing user preferences.
    static var customMirrorSite: String {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: customMirrorSiteKey),
           let normalized = normalizedCustomMirrorURL(from: stored) {
            return normalized
        }
        guard let legacy = defaults.string(forKey: preferenceKey),
              !isPreset(legacy) else {
            return ""
        }
        return normalizedCustomMirrorURL(from: legacy) ?? ""
    }

    static var usesCustomMirror: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: useCustomMirrorKey) != nil {
            return defaults.bool(forKey: useCustomMirrorKey) && !customMirrorSite.isEmpty
        }
        // Legacy iOS builds represented an active custom mirror by putting it
        // directly in `domain_name`.
        return !customMirrorSite.isEmpty
    }

    static var appendsCustomMirrorPath: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: appendCustomMirrorPathKey) != nil else {
            return true
        }
        return defaults.bool(forKey: appendCustomMirrorPathKey)
    }

    /// Exact URL used to request the homepage.
    static var currentHomeURL: String {
        usesCustomMirror ? customMirrorSite : selectedPresetURL
    }

    /// Base used by `/search`, `/watch`, `/login`, comments, and user APIs.
    static var currentBaseURL: String {
        guard usesCustomMirror else { return selectedPresetURL }
        if appendsCustomMirrorPath {
            return customMirrorSite
        }
        return rootURL(from: customMirrorSite) ?? selectedPresetURL
    }

    static var currentHost: String {
        URLComponents(string: currentHomeURL)?.host?.lowercased() ?? "hanime1.me"
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

    static func applyPreset(_ url: String) {
        guard let normalized = normalizedPresetURL(url) else { return }
        let defaults = UserDefaults.standard
        defaults.set(normalized, forKey: preferenceKey)
        defaults.set(normalized, forKey: selectedBaseURLKey)
        defaults.set(false, forKey: useCustomMirrorKey)
    }

    static func applyCustomMirror(url: String, appendPath: Bool, enabled: Bool) {
        guard !enabled || normalizedCustomMirrorURL(from: url) != nil else { return }
        let defaults = UserDefaults.standard
        if let normalized = normalizedCustomMirrorURL(from: url) {
            defaults.set(normalized, forKey: customMirrorSiteKey)
        } else if !enabled {
            defaults.set("", forKey: customMirrorSiteKey)
        }
        defaults.set(appendPath, forKey: appendCustomMirrorPathKey)
        defaults.set(enabled, forKey: useCustomMirrorKey)
        defaults.set(selectedPresetURL, forKey: preferenceKey)
        defaults.set(selectedPresetURL, forKey: selectedBaseURLKey)
    }

    static func isPreset(_ url: String) -> Bool {
        normalizedPresetURL(url) != nil
    }

    static func displayHost(for url: String) -> String {
        URLComponents(string: url)?.host ?? url
    }

    static func normalizedCustomMirrorURL(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }
        components.scheme = "https"
        components.host = host.lowercased()
        if components.path.count > 1 {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/\(components.path)"
        } else {
            components.path = ""
        }
        return components.url?.absoluteString
    }

    static func apiBaseURL(homeURL: String, appendPath: Bool) -> String? {
        guard let normalized = normalizedCustomMirrorURL(from: homeURL) else { return nil }
        return appendPath ? normalized : rootURL(from: normalized)
    }

    static func appending(_ path: String, to baseURL: String) -> URL? {
        guard let base = URL(string: baseURL) else { return nil }
        return base.appendingPathComponent(path)
    }

    private static func normalizedPresetURL(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return options.first { $0.url == trimmed }?.url
    }

    private static func rootURL(from url: String) -> String? {
        guard var components = URLComponents(string: url), components.host != nil else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString
    }
}

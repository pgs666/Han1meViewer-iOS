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

    /// Reads the persisted domain, normalising any stored value (older
    /// builds may have stored a trailing slash) and falling back to the
    /// default if it's empty or not one of the known options.
    static var currentBaseURL: String {
        let stored = UserDefaults.standard.string(forKey: preferenceKey)?
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/", with: "", options: .anchored)
        guard let stored, !stored.isEmpty else { return defaultBaseURL }
        let normalized = stored.hasSuffix("/") ? String(stored.dropLast()) : stored
        return options.first { $0.url == normalized }?.url ?? defaultBaseURL
    }

    static func setBaseURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: preferenceKey)
    }
}

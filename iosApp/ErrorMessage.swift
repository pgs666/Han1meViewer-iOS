import Foundation

enum ErrorMessage {
    static func userFriendly(_ error: Error) -> String {
        let raw = error.localizedDescription
        let lowercased = raw.lowercased()

        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return "The request timed out. Check your network and try again."
        }
        if lowercased.contains("cloudflare") || lowercased.contains("forbidden") || lowercased.contains("403") {
            CloudflareChallengeCenter.requestChallenge()
            return "The site blocked this request. Complete the browser challenge, then try again."
        }
        if lowercased.contains("could not connect") || lowercased.contains("network") || lowercased.contains("offline") {
            return "Network connection failed. Check Wi-Fi or VPN and try again."
        }
        if raw.isEmpty {
            return "Something went wrong. Please try again."
        }
        return raw
    }
}

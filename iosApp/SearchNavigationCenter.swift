import Foundation

enum SearchNavigationCenter {
    static let requestNotification = Notification.Name("SearchNavigationCenter.request")
    static let keywordKey = "keyword"

    static func open(keyword: String) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            return
        }

        NotificationCenter.default.post(
            name: requestNotification,
            object: nil,
            userInfo: [keywordKey: trimmedKeyword]
        )
    }
}

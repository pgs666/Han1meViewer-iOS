import Foundation

struct SearchLaunchRequest: Equatable, Identifiable {
    let id = UUID()
    let sectionKey: String
    let sectionTitle: String
    let keyword: String?

    init(sectionKey: String, sectionTitle: String, keyword: String? = nil) {
        self.sectionKey = sectionKey
        self.sectionTitle = sectionTitle
        self.keyword = keyword
    }
}

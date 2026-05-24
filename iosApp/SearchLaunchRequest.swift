import Foundation

struct SearchLaunchRequest: Equatable, Identifiable {
    let id = UUID()
    let sectionKey: String
    let sectionTitle: String
}

import SwiftUI

/// Pushed sub-page of SettingsView that lets the user reorder the home
/// page's category sections. Persists the new order to NSUserDefaults
/// at key `home_section_order` (comma-joined section keys), which
/// HomeView reads via @AppStorage and applies on the next render —
/// so the change is live the moment the user backs out of this page.
struct HomeSectionOrderView: View {
    @AppStorage("home_section_order") private var orderRaw: String = ""
    @State private var items: [SectionItem] = []

    /// All known home-section keys, in the upstream HTML's natural order.
    /// Mirrors `KsoupHtmlParser.HOME_SECTION_MAPPINGS`. New sections
    /// added there in the future should be added here too — otherwise
    /// they won't show up in this picker (HomeView will still render
    /// them at the end of the list because of the trailing-merge logic
    /// in `orderedSections`, but the user won't be able to drag them).
    private static let allSectionKeys: [String] = [
        "latestRelease",
        "latestHanime",
        "ecchiAnime",
        "shortEpisodeAnime",
        "motionAnime",
        "threeDCG",
        "twoPointFiveDAnime",
        "twoDAnime",
        "aiGenerated",
        "mmd",
        "cosplay",
        "watchingNow",
        "newAnimeTrailer",
    ]

    private struct SectionItem: Identifiable, Equatable {
        let key: String
        var id: String { key }
        var title: String { HomeSectionRow.localizedTitle(for: key) }
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Text(item.title)
                }
                .onMove(perform: moveItems)
            } header: {
                Text("拖动右侧把手调整顺序，调整会立即应用到首页。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .navigationTitle("首页栏目排序")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnAppear()
        // Forcing edit-mode .active ensures the right-side reorder
        // handles are always visible — no manual "Edit" button.
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("重置") {
                    items = HomeSectionOrderView.allSectionKeys.map { SectionItem(key: $0) }
                    orderRaw = ""
                }
                .foregroundStyle(.primary)
            }
        }
        .onAppear(perform: loadOrder)
    }

    private func loadOrder() {
        let saved = orderRaw
            .split(separator: ",")
            .map(String.init)
            .filter { HomeSectionOrderView.allSectionKeys.contains($0) }
        var seen = Set<String>()
        var ordered: [SectionItem] = []
        for key in saved where !seen.contains(key) {
            ordered.append(SectionItem(key: key))
            seen.insert(key)
        }
        for key in HomeSectionOrderView.allSectionKeys where !seen.contains(key) {
            ordered.append(SectionItem(key: key))
        }
        items = ordered
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        orderRaw = items.map(\.key).joined(separator: ",")
    }
}

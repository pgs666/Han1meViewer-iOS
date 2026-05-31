import SwiftUI

/// Pushed sub-page of SettingsView that lets the user reorder AND hide
/// home-page category sections. State is split across two NSUserDefaults
/// keys (HomeView reads both via @AppStorage and applies them on the next
/// render — the change is live the moment the user backs out):
///
/// - `home_section_order`  — comma-joined keys of VISIBLE sections, in
///   user-preferred order. Empty = use the order the server returned for
///   visible sections.
/// - `home_section_hidden` — comma-joined keys of HIDDEN sections.
///   Defaults to `aiGenerated` so a fresh install hides AI-generated
///   anime out of the box.
///
/// UX: the page shows two big sections, "已显示" on top and "已隐藏" on
/// the bottom. Within each section, drag the right-side reorder handle
/// to change order. To MOVE a row between sections, swipe the row left
/// (trailing edge) and tap the revealed action button:
///
///   - In 已显示: swipe → "隐藏" → row moves to 已隐藏 (appended)
///   - In 已隐藏: swipe → "显示" → row moves to 已显示 (appended)
///
/// We previously tried .draggable + .dropDestination and the older
/// .onDrag + .onInsert combos for cross-section drag. Both were either
/// silently swallowed by .onMove (the new combo) or fragile (the old
/// one didn't reliably trigger when paired with edit-mode reorder
/// handles). Swipe actions don't fight any other gesture and match the
/// platform-standard idiom users already know from Mail / Messages.
struct HomeSectionOrderView: View {
    @AppStorage("home_section_order") private var visibleRaw: String = ""
    @AppStorage("home_section_hidden") private var hiddenRaw: String = "aiGenerated"

    @State private var visibleItems: [SectionItem] = []
    @State private var hiddenItems: [SectionItem] = []

    /// All known home-section keys, in the upstream HTML's natural order.
    /// Mirrors `KsoupHtmlParser.HOME_SECTION_MAPPINGS`. Keys present here
    /// but absent from saved state are treated as visible-by-default
    /// (except those listed in `defaultHiddenKeys`).
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

    /// Sections hidden by default on a fresh install (also the destination
    /// when the user taps "重置"). Mirrors the @AppStorage default of
    /// `hiddenRaw`.
    private static let defaultHiddenKeys: Set<String> = ["aiGenerated"]

    private struct SectionItem: Identifiable, Equatable {
        let key: String
        var id: String { key }
        var title: String { HomeSectionRow.localizedTitle(for: key) }
    }

    var body: some View {
        List {
            Section {
                if visibleItems.isEmpty {
                    Text("无可显示栏目")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                ForEach(visibleItems) { item in
                    Text(item.title)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                hide(item.key)
                            } label: {
                                Label("隐藏", systemImage: "eye.slash")
                            }
                            .tint(.gray)
                        }
                }
                .onMove(perform: moveVisibleItems)
            } header: {
                Text("已显示")
            } footer: {
                Text("长按一行可在本组内拖动调整顺序;向左滑动一行可在两组之间移动。")
                    .font(.caption)
            }

            Section {
                if hiddenItems.isEmpty {
                    Text("无隐藏栏目")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                ForEach(hiddenItems) { item in
                    Text(item.title)
                        .foregroundStyle(.secondary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                show(item.key)
                            } label: {
                                Label("显示", systemImage: "eye")
                            }
                            .tint(.accentColor)
                        }
                }
                .onMove(perform: moveHiddenItems)
            } header: {
                Text("已隐藏")
            }
        }
        .navigationTitle("首页栏目排序")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnAppear()
        // NOTE: do NOT force editMode to .active here. With editMode
        // active, SwiftUI reserves the trailing edge for the reorder
        // handle and silently disables `.swipeActions`, so the user
        // can't swipe to hide/show. iOS 15+ supports `.onMove` without
        // edit mode — the user long-presses any row, gets a haptic,
        // and drags to reorder within the section. Swipe-left then
        // works as expected for the cross-section move.
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("重置") {
                    resetToDefaults()
                }
                .foregroundStyle(.primary)
            }
        }
        .onAppear(perform: loadOrder)
    }

    // MARK: - Loading / persistence

    private func loadOrder() {
        let savedHidden = parse(hiddenRaw)
        let savedVisible = parse(visibleRaw)

        var seen = Set<String>()
        var hidden: [SectionItem] = []
        var visible: [SectionItem] = []

        // Hidden first so existing saved hidden keys win over saved visible
        // (defensive: a key shouldn't appear in both lists, but be explicit).
        for key in savedHidden where !seen.contains(key) {
            hidden.append(SectionItem(key: key))
            seen.insert(key)
        }
        for key in savedVisible where !seen.contains(key) {
            visible.append(SectionItem(key: key))
            seen.insert(key)
        }
        // Any key never seen — newly added to the parser since last save —
        // goes to visible by default (unless it's in the defaults-hidden
        // list).
        for key in Self.allSectionKeys where !seen.contains(key) {
            if Self.defaultHiddenKeys.contains(key) {
                hidden.append(SectionItem(key: key))
            } else {
                visible.append(SectionItem(key: key))
            }
        }

        visibleItems = visible
        hiddenItems = hidden
    }

    private func parse(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter {
            Self.allSectionKeys.contains($0)
        }
    }

    private func save() {
        visibleRaw = visibleItems.map(\.key).joined(separator: ",")
        hiddenRaw = hiddenItems.map(\.key).joined(separator: ",")
    }

    // MARK: - Mutations

    private func moveVisibleItems(from source: IndexSet, to destination: Int) {
        visibleItems.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func moveHiddenItems(from source: IndexSet, to destination: Int) {
        hiddenItems.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func hide(_ key: String) {
        guard let i = visibleItems.firstIndex(where: { $0.key == key }) else { return }
        let item = visibleItems.remove(at: i)
        withAnimation {
            hiddenItems.append(item)
        }
        save()
    }

    private func show(_ key: String) {
        guard let i = hiddenItems.firstIndex(where: { $0.key == key }) else { return }
        let item = hiddenItems.remove(at: i)
        withAnimation {
            visibleItems.append(item)
        }
        save()
    }

    private func resetToDefaults() {
        visibleItems = Self.allSectionKeys
            .filter { !Self.defaultHiddenKeys.contains($0) }
            .map { SectionItem(key: $0) }
        hiddenItems = Self.allSectionKeys
            .filter { Self.defaultHiddenKeys.contains($0) }
            .map { SectionItem(key: $0) }
        save()
    }
}

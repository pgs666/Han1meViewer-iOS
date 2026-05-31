import SwiftUI
import UniformTypeIdentifiers

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
/// the bottom. Each row carries the standard right-side reorder handle
/// (active edit mode) and is also draggable from its content body.
///
/// Why this is the only shape that works: SwiftUI's `.onMove` only fires
/// for within-section reorders — Apple confirms this in their dev forums
/// and the modern `.draggable` + `.dropDestination` combo silently
/// refuses to deliver drops onto a List section that also has `.onMove`.
/// The reliable cross-section path is the older `.onDrag(NSItemProvider)`
/// + `ForEach.onInsert(of:perform:)` pair, which coexists with
/// `.onMove` because they handle disjoint events:
///
///   - `.onMove`   → row dragged within its own ForEach
///   - `.onInsert` → item dropped onto this ForEach from elsewhere
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
                    row(for: item)
                }
                .onMove(perform: moveVisibleItems)
                .onInsert(of: [UTType.plainText.identifier], perform: insertIntoVisible)
            } header: {
                Text("已显示")
            } footer: {
                Text("拖动右侧把手可在本组内调整顺序;长按一行的内容并把它拖到下方「已隐藏」组以从首页隐藏(反之亦然以重新显示)。")
                    .font(.caption)
            }

            Section {
                if hiddenItems.isEmpty {
                    Text("无隐藏栏目")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                ForEach(hiddenItems) { item in
                    row(for: item, dimmed: true)
                }
                .onMove(perform: moveHiddenItems)
                .onInsert(of: [UTType.plainText.identifier], perform: insertIntoHidden)
            } header: {
                Text("已隐藏")
            }
        }
        .navigationTitle("首页栏目排序")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnAppear()
        // Edit mode active so the right-side reorder handles are always
        // visible — no manual "Edit" toolbar button.
        .environment(\.editMode, .constant(.active))
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

    @ViewBuilder
    private func row(for item: SectionItem, dimmed: Bool = false) -> some View {
        Text(item.title)
            .foregroundStyle(dimmed ? .secondary : .primary)
            // .onDrag fires when the user long-presses the row content
            // (NOT the right-side reorder handle). The handle still owns
            // the in-section reorder gesture via .onMove. The dragged
            // payload is just the section key as plain text — small and
            // identity-stable across the two ForEach instances.
            .onDrag { NSItemProvider(object: item.key as NSString) }
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

    private func insertIntoVisible(at index: Int, items: [NSItemProvider]) {
        loadKeys(from: items) { keys in
            self.applyCrossSectionMove(keys: keys, into: .visible, at: index)
        }
    }

    private func insertIntoHidden(at index: Int, items: [NSItemProvider]) {
        loadKeys(from: items) { keys in
            self.applyCrossSectionMove(keys: keys, into: .hidden, at: index)
        }
    }

    private enum DropTarget { case visible, hidden }

    /// NSItemProvider.loadObject is async + on a background queue. Collect
    /// every successfully decoded key, then deliver them as a single batch
    /// on the main queue so the @State mutations and `save()` happen
    /// atomically (not interleaved if the user dropped a multi-selection).
    private func loadKeys(from providers: [NSItemProvider], handle: @escaping ([String]) -> Void) {
        guard !providers.isEmpty else { return }
        let group = DispatchGroup()
        var collected: [String] = []
        let lock = NSLock()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
                if let s = obj as? String {
                    lock.lock(); collected.append(s); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !collected.isEmpty { handle(collected) }
        }
    }

    private func applyCrossSectionMove(keys: [String], into target: DropTarget, at index: Int) {
        var moved: [SectionItem] = []
        for key in keys {
            // Take the item out of whichever list it currently lives in.
            // Skip silently if it's not in the OTHER list — that means
            // the user dragged a row onto its own ForEach (which already
            // produced an .onMove for in-section reorder, and this
            // .onInsert is a duplicate event we should ignore).
            switch target {
            case .visible:
                if let i = hiddenItems.firstIndex(where: { $0.key == key }) {
                    moved.append(hiddenItems.remove(at: i))
                }
            case .hidden:
                if let i = visibleItems.firstIndex(where: { $0.key == key }) {
                    moved.append(visibleItems.remove(at: i))
                }
            }
        }
        guard !moved.isEmpty else { return }
        switch target {
        case .visible:
            let safe = max(0, min(index, visibleItems.count))
            visibleItems.insert(contentsOf: moved, at: safe)
        case .hidden:
            let safe = max(0, min(index, hiddenItems.count))
            hiddenItems.insert(contentsOf: moved, at: safe)
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

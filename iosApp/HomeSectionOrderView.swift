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
/// (active edit mode), so dragging the handle reorders within its
/// section. To move a row to the OTHER section, long-press anywhere on
/// the row and drop it onto the explicit "拖动到这里…" footer row of
/// the destination section.
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
                        .draggable(item.key)
                }
                .onMove(perform: moveVisibleItems)
                dropFooter(label: "拖动到这里以显示", into: .visible)
            } header: {
                Text("已显示")
            } footer: {
                Text("拖动右侧把手调整顺序，或把行拖到下方「已隐藏」区域以从首页隐藏。")
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
                        .draggable(item.key)
                }
                .onMove(perform: moveHiddenItems)
                dropFooter(label: "拖动到这里以隐藏", into: .hidden)
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

    private enum DropTarget {
        case visible
        case hidden
    }

    @ViewBuilder
    private func dropFooter(label: LocalizedStringKey, into target: DropTarget) -> some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .center)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary.opacity(0.4))
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .moveDisabled(true)
            .dropDestination(for: String.self) { keys, _ in
                applyDrop(keys: keys, into: target)
                return true
            }
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

    private func applyDrop(keys: [String], into target: DropTarget) {
        var changed = false
        for key in keys {
            switch target {
            case .visible:
                if let idx = hiddenItems.firstIndex(where: { $0.key == key }) {
                    let item = hiddenItems.remove(at: idx)
                    visibleItems.append(item)
                    changed = true
                }
            case .hidden:
                if let idx = visibleItems.firstIndex(where: { $0.key == key }) {
                    let item = visibleItems.remove(at: idx)
                    hiddenItems.append(item)
                    changed = true
                }
            }
        }
        if changed { save() }
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

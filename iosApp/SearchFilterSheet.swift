import SwiftUI
import Han1meShared

struct SearchFilterSheet: View {
    let catalog: SearchOptionCatalog
    let initialFilters: SearchFilterState
    let onApply: (SearchFilterState) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: SearchFilterState
    @State private var selectedTagSectionID: String?
    @State private var isBrandSectionExpanded: Bool

    init(
        catalog: SearchOptionCatalog,
        initialFilters: SearchFilterState,
        onApply: @escaping (SearchFilterState) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.catalog = catalog
        self.initialFilters = initialFilters
        self.onApply = onApply
        self.onReset = onReset
        _draft = State(initialValue: initialFilters)
        _selectedTagSectionID = State(initialValue: catalog.tagSections.first?.id)
        _isBrandSectionExpanded = State(initialValue: !initialFilters.brands.isEmpty)
    }

    var body: some View {
        CompatibleNavigationStack {
            List {
                singleChoiceSection(
                    title: "类型",
                    options: catalog.genres,
                    selection: $draft.genre
                )
                singleChoiceSection(
                    title: "排序方式",
                    options: catalog.sortOptions,
                    selection: $draft.sort
                )
                brandSection
                tagSection
                singleChoiceSection(
                    title: "发布日期",
                    options: catalog.releaseDates,
                    selection: $draft.releaseDate
                )
                singleChoiceSection(
                    title: "影片时长",
                    options: catalog.durations,
                    selection: $draft.duration
                )
            }
            .navigationTitle("筛选")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        draft.reset()
                        onReset()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onApply(draft)
                        dismiss()
                    }
                    .font(.headline)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        onApply(draft)
                        dismiss()
                    } label: {
                        Label("应用筛选", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func singleChoiceSection(
        title: String,
        options: [SearchFilterOption],
        selection: Binding<SearchFilterOption?>
    ) -> some View {
        Section {
            if options.isEmpty {
                Text("筛选项加载失败。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(options) { option in
                    Button {
                        if option.searchKey == nil || option.searchKey == "全部" {
                            selection.wrappedValue = nil
                        } else {
                            selection.wrappedValue = option
                        }
                    } label: {
                        HStack {
                            Text(option.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selection.wrappedValue == option ||
                                (selection.wrappedValue == nil && (option.searchKey == nil || option.searchKey == "全部")) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                if selection.wrappedValue != nil {
                    Button("清除") {
                        selection.wrappedValue = nil
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var brandSection: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isBrandSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    Label(
                        draft.brands.isEmpty ? "选择品牌" : "已选择 \(draft.brands.count) 个品牌",
                        systemImage: "building.2"
                    )
                    .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isBrandSectionExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isBrandSectionExpanded {
                if catalog.brands.isEmpty {
                    Text("品牌加载失败。")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(catalog.brands) { option in
                            SearchTagChip(
                                title: option.displayName,
                                isSelected: draft.brands.contains(option),
                                onTap: {
                                    if draft.brands.contains(option) {
                                        draft.brands.remove(option)
                                    } else {
                                        draft.brands.insert(option)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        } header: {
            HStack {
                Text(draft.brands.isEmpty ? String(localized: "品牌") : String(format: String(localized: "search.brands.count"), draft.brands.count))
                Spacer()
                if !draft.brands.isEmpty {
                    Button("清除") {
                        draft.brands.removeAll()
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var tagSection: some View {
        Section {
            Toggle(isOn: $draft.broad) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("模糊搜索")
                    Text("匹配包含任一已选标签的影片。关闭时更接近精确组合。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if catalog.tagSections.isEmpty {
                Text("标签加载失败。")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(catalog.tagSections) { section in
                            Button {
                                selectedTagSectionID = section.id
                            } label: {
                                Text(section.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(minWidth: 86)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(selectedTagSectionID == section.id ? Color.accentColor : Color.secondary)
                                    .background(
                                        selectedTagSectionID == section.id ? Color.accentColor.opacity(0.14) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .padding(.vertical, 4)
                }

                if let section = selectedTagSection {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(section.options) { option in
                            SearchTagChip(
                                title: option.displayName,
                                isSelected: draft.tags.contains(option),
                                onTap: {
                                    if draft.tags.contains(option) {
                                        draft.tags.remove(option)
                                    } else {
                                        draft.tags.insert(option)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        } header: {
            HStack {
                Text(draft.tags.isEmpty ? String(localized: "标签") : String(format: String(localized: "search.tags.count"), draft.tags.count))
                Spacer()
                if !draft.tags.isEmpty {
                    Button("清除") {
                        draft.tags.removeAll()
                    }
                    .font(.caption)
                }
            }
        } footer: {
            Text("标签选项与 Android 版 search_options 保持一致。")
        }
    }

    private var selectedTagSection: SearchTagSection? {
        catalog.tagSections.first { $0.id == selectedTagSectionID } ?? catalog.tagSections.first
    }
}

struct SearchTagChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

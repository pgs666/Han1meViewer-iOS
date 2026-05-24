import SwiftUI
import Han1meShared

struct SearchView: View {
    @State private var keyword = ""
    @State private var isShowingFilters = false
    @StateObject private var viewModel: SearchViewModel
    private let environment: SharedAppEnvironment
    private let catalog = SearchOptionCatalog.shared

    init(environment: SharedAppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: SearchViewModel(searchFeature: environment.searchFeature()))
    }

    var body: some View {
        NavigationView {
            content
            .navigationTitle("搜索")
            .searchable(
                text: $keyword,
                placement: .automatic,
                prompt: "搜索影片、标签或作者"
            )
            .onSubmit(of: .search) {
                viewModel.search(keyword: keyword)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                            if viewModel.filters.activeCount > 0 {
                                Text("\(viewModel.filters.activeCount)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                                    .offset(x: 9, y: -9)
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadHistoryIfNeeded()
            }
            .sheet(isPresented: $isShowingFilters) {
                SearchFilterSheet(
                    catalog: catalog,
                    initialFilters: viewModel.filters,
                    onApply: { filters in
                        viewModel.search(keyword: keyword, filters: filters)
                    },
                    onReset: {
                        viewModel.resetFilters()
                        viewModel.search(keyword: keyword, filters: SearchFilterState())
                    }
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleContent
        case .loading:
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("搜索失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    viewModel.search(keyword: keyword)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot), .loadingMore(let snapshot):
            resultList(snapshot: snapshot)
        }
    }

    private var idleContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.filters.summaryItems.isEmpty {
                    filterSummary
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("浏览分类")
                            .font(.title2.weight(.bold))
                        Spacer()
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14),
                        ],
                        spacing: 14
                    ) {
                        ForEach(browseCards) { card in
                            Button {
                                isShowingFilters = true
                            } label: {
                                SearchBrowseCard(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !viewModel.history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最近搜索")
                                .font(.title2.weight(.bold))
                            Spacer()
                            Button("清空") {
                                viewModel.clearHistory()
                            }
                            .font(.caption)
                        }

                        VStack(spacing: 0) {
                            ForEach(viewModel.history, id: \.self) { item in
                                Button {
                                    keyword = item
                                    viewModel.search(keyword: item)
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundStyle(.secondary)
                                        Text(item)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 13)
                                }
                                if item != viewModel.history.last {
                                    Divider()
                                        .padding(.leading, 28)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color(.systemBackground))
    }

    private var filterSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已选筛选")
                    .font(.title3.weight(.bold))
                Spacer()
                Button("清除") {
                    viewModel.resetFilters()
                    viewModel.search(keyword: keyword, filters: SearchFilterState())
                }
                .font(.caption)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.filters.summaryItems, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.red.opacity(0.12), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func resultList(snapshot: SearchScreenSnapshot) -> some View {
        List {
            Section {
                if snapshot.results.isEmpty {
                    Text("没有找到结果。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.results) { video in
                        NavigationLink {
                            VideoDetailView(
                                videoCode: video.videoCode,
                                videoFeature: environment.videoFeature()
                            )
                        } label: {
                            SearchResultRow(video: video)
                        }
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentItemID: video.id)
                        }
                    }
                    searchFooter(snapshot: snapshot)
                }
            } header: {
                HStack {
                    Text("结果")
                    Spacer()
                    Text("\(snapshot.results.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func searchFooter(snapshot: SearchScreenSnapshot) -> some View {
        switch viewModel.state {
        case .loadingMore:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 10)
        default:
            if let message = snapshot.loadMoreError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("加载更多失败")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("重试") {
                        viewModel.loadMoreIfNeeded(currentItemID: snapshot.results.last?.id)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 8)
            } else if snapshot.hasNext {
                HStack {
                    Spacer()
                    ProgressView()
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentItemID: snapshot.results.last?.id)
                        }
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if !snapshot.results.isEmpty {
                Text("已全部加载")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    private var browseCards: [SearchBrowseCardModel] {
        [
            SearchBrowseCardModel(title: "类型", systemImage: "square.grid.2x2.fill", colors: [.red, .pink]),
            SearchBrowseCardModel(title: "排序", systemImage: "arrow.up.arrow.down", colors: [.pink, .purple]),
            SearchBrowseCardModel(title: "影片属性", systemImage: "sparkles", colors: [.orange, .yellow]),
            SearchBrowseCardModel(title: "标签", systemImage: "tag.fill", colors: [.red, .orange]),
            SearchBrowseCardModel(title: "发布日期", systemImage: "calendar", colors: [.blue, .cyan]),
            SearchBrowseCardModel(title: "影片时长", systemImage: "clock.fill", colors: [.indigo, .blue]),
            SearchBrowseCardModel(title: "人物关系", systemImage: "person.2.fill", colors: [.purple, .pink]),
            SearchBrowseCardModel(title: "情景场所", systemImage: "map.fill", colors: [.green, .teal]),
        ]
    }
}

private struct SearchBrowseCardModel: Identifiable {
    let title: String
    let systemImage: String
    let colors: [Color]

    var id: String { title }
}

private struct SearchBrowseCard: View {
    let card: SearchBrowseCardModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: card.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: card.systemImage)
                .font(.system(size: 58, weight: .bold))
                .foregroundColor(.white.opacity(0.28))
                .rotationEffect(.degrees(-8))
                .offset(x: 44, y: -22)
            Text(card.title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(16)
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SearchFilterSheet: View {
    let catalog: SearchOptionCatalog
    let initialFilters: SearchFilterState
    let onApply: (SearchFilterState) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: SearchFilterState
    @State private var selectedTagSectionID: String?

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
    }

    var body: some View {
        NavigationView {
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
        .navigationViewStyle(.stack)
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
                                .foregroundColor(.primary)
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
                    HStack(spacing: 8) {
                        ForEach(catalog.tagSections) { section in
                            Button {
                                selectedTagSectionID = section.id
                            } label: {
                                Text(section.title)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedTagSectionID == section.id
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.secondary.opacity(0.10),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                Text(draft.tags.isEmpty ? "标签" : "标签（\(draft.tags.count)）")
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

private struct SearchTagChip: View {
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
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultRow: View {
    let video: SearchVideoRow

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: video.coverUrl)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .lineLimit(2)
                if !video.metadata.isEmpty {
                    Text(video.metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

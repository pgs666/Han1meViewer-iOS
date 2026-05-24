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
            VStack(spacing: 0) {
                searchHeader
                content
            }
            .navigationTitle("搜索")
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

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索影片、标签或作者", text: $keyword)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit {
                            viewModel.search(keyword: keyword)
                        }

                    if !keyword.isEmpty {
                        Button {
                            keyword = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    isShowingFilters = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 38, height: 38)
                        if viewModel.filters.activeCount > 0 {
                            Text("\(viewModel.filters.activeCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor))
                                .offset(x: 4, y: -5)
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            Button {
                viewModel.search(keyword: keyword)
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .searchProminentGlassButton()
            .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.filters.hasActiveFilters)

            if !viewModel.filters.summaryItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.filters.summaryItems, id: \.self) { item in
                            Text(item)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(.primary)
                        }

                        Button {
                            viewModel.resetFilters()
                        } label: {
                            Label("清除", systemImage: "xmark")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color(.systemGroupedBackground))
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
        List {
            Section {
                Button {
                    isShowingFilters = true
                } label: {
                    Label("打开筛选面板", systemImage: "slider.horizontal.3")
                }

                if keyword.isEmpty {
                    Text("输入关键词，或使用筛选面板开始高级搜索。")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("搜索")
            }

            if !viewModel.history.isEmpty {
                Section {
                    ForEach(viewModel.history, id: \.self) { item in
                        Button {
                            keyword = item
                            viewModel.search(keyword: item)
                        } label: {
                            Label(item, systemImage: "clock.arrow.circlepath")
                        }
                    }
                } header: {
                    HStack {
                        Text("最近搜索")
                        Spacer()
                        Button("清空") {
                            viewModel.clearHistory()
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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

private extension View {
    @ViewBuilder
    func searchProminentGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            self.buttonStyle(LiquidGlassSearchButtonStyle())
        }
    }
}

private struct LiquidGlassSearchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .foregroundStyle(.primary)
            .background {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(configuration.isPressed ? 0.10 : 0.28),
                                    Color.white.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.16), radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

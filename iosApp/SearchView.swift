import SwiftUI
import UIKit
import Han1meShared

struct SearchView: View {
    @State private var keyword = ""
    @State private var isShowingFilters = false
    @State private var catalog = SearchOptionCatalog.empty
    @StateObject private var viewModel: SearchViewModel
    @Binding private var launchRequest: SearchLaunchRequest?
    private let videoFeature: VideoFeature
    private let commentFeature: CommentFeature

    init(environment: SharedAppEnvironment, launchRequest: Binding<SearchLaunchRequest?> = .constant(nil)) {
        self.videoFeature = environment.videoFeature()
        self.commentFeature = environment.commentFeature()
        _launchRequest = launchRequest
        _viewModel = StateObject(wrappedValue: SearchViewModel(searchFeature: environment.searchFeature()))
    }

    var body: some View {
        CompatibleNavigationStack {
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
            .background(SearchTextFieldReturnKeyEnabler())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(viewModel.filters.activeCount > 0 ? Color.accentColor : Color.primary)
                    }
                    .tint(viewModel.filters.activeCount > 0 ? Color.accentColor : Color.primary)
                }
            }
            .onAppear {
                viewModel.loadHistoryIfNeeded()
                consumeLaunchRequestIfNeeded()
            }
            .task {
                await loadCatalogIfNeeded()
                consumeLaunchRequestIfNeeded()
            }
            .onValueChange(of: launchRequest?.id) { _ in
                consumeLaunchRequestIfNeeded()
            }
            .onValueChange(of: catalog.isLoaded) { _ in
                consumeLaunchRequestIfNeeded()
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
                    .foregroundStyle(.secondary)
                Text("搜索失败")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        Group {
            if viewModel.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("暂无搜索历史")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("搜索历史")
                                .font(.title2.weight(.bold))
                            Spacer()
                            Button("清空") {
                                viewModel.clearHistory()
                            }
                            .font(.caption)
                        }

                        VStack(spacing: 0) {
                            ForEach(viewModel.history) { item in
                                Button {
                                    keyword = item.keyword
                                    viewModel.search(keyword: item.keyword)
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)

                                            if item.hasKeyword && item.hasFilterSummary {
                                                Text(item.filterSummary)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 13)
                                }
                                if item.id != viewModel.history.last?.id {
                                    Divider()
                                        .padding(.leading, 28)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .background(Color(.systemBackground))
            }
        }
    }

    private func consumeLaunchRequestIfNeeded() {
        guard let request = launchRequest else {
            return
        }
        guard catalog.isLoaded else {
            return
        }
        keyword = ""
        if let requestKeyword = request.keyword {
            keyword = requestKeyword
            viewModel.search(keyword: requestKeyword, recordHistory: false)
        } else {
            viewModel.openHomeSection(request, catalog: catalog)
        }
        launchRequest = nil
    }

    private func loadCatalogIfNeeded() async {
        guard !catalog.isLoaded else {
            return
        }
        catalog = await Task.detached(priority: .utility) {
            SearchOptionCatalog()
        }.value
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
                                videoFeature: videoFeature,
                                commentFeature: commentFeature
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
                    Button {
                        keyword = ""
                        viewModel.showHistory()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("返回搜索历史")
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

private struct SearchTextFieldReturnKeyEnabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            uiView.window?.setSearchReturnKeyEnabled()
        }
    }
}

private extension UIView {
    func setSearchReturnKeyEnabled() {
        if let searchTextField = self as? UISearchTextField {
            searchTextField.enablesReturnKeyAutomatically = false
        }

        subviews.forEach { subview in
            subview.setSearchReturnKeyEnabled()
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

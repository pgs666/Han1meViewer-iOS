import Foundation

struct SearchOptionCatalog: Sendable {
    let genres: [SearchFilterOption]
    let sortOptions: [SearchFilterOption]
    let durations: [SearchFilterOption]
    let releaseDates: [SearchFilterOption]
    let brands: [SearchFilterOption]
    let tagSections: [SearchTagSection]

    static let shared = SearchOptionCatalog()
    static let empty = SearchOptionCatalog(
        genres: [],
        sortOptions: [],
        durations: [],
        releaseDates: [],
        brands: [],
        tagSections: []
    )

    private init(
        genres: [SearchFilterOption],
        sortOptions: [SearchFilterOption],
        durations: [SearchFilterOption],
        releaseDates: [SearchFilterOption],
        brands: [SearchFilterOption],
        tagSections: [SearchTagSection]
    ) {
        self.genres = genres
        self.sortOptions = sortOptions
        self.durations = durations
        self.releaseDates = releaseDates
        self.brands = brands
        self.tagSections = tagSections
    }

    var isLoaded: Bool {
        !genres.isEmpty || !sortOptions.isEmpty || !durations.isEmpty || !releaseDates.isEmpty || !brands.isEmpty || !tagSections.isEmpty
    }

    init(bundle: Bundle = .main) {
        genres = SearchOptionCatalog.loadArray("genre", bundle: bundle)
        sortOptions = SearchOptionCatalog.loadArray("sort_option", bundle: bundle)
        durations = SearchOptionCatalog.loadArray("duration", bundle: bundle)
        releaseDates = SearchOptionCatalog.loadArray("release_date", bundle: bundle)
        brands = SearchOptionCatalog.loadArray("brands", bundle: bundle)
        tagSections = SearchOptionCatalog.loadTagSections(bundle: bundle)
    }

    private static func loadArray(_ name: String, bundle: Bundle) -> [SearchFilterOption] {
        guard let url = resourceURL(name, bundle: bundle),
              let data = try? Data(contentsOf: url),
              let options = try? JSONDecoder().decode([SearchFilterOption].self, from: data) else {
            return []
        }
        return options
    }

    private static func loadTagSections(bundle: Bundle) -> [SearchTagSection] {
        guard let url = resourceURL("tags", bundle: bundle),
              let data = try? Data(contentsOf: url),
              let rawSections = try? JSONDecoder().decode([String: [SearchFilterOption]].self, from: data) else {
            return []
        }

        return tagSectionOrder.compactMap { key, title in
            guard let options = rawSections[key], !options.isEmpty else {
                return nil
            }
            return SearchTagSection(key: key, title: title, options: options)
        }
    }

    private static func resourceURL(_ name: String, bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: "json", subdirectory: "SearchOptions")
            ?? bundle.url(forResource: name, withExtension: "json")
    }

    private static let tagSectionOrder: [(String, String)] = [
        ("video_attributes", "影片属性"),
        ("character_relationships", "人物关系"),
        ("characteristics", "角色设定"),
        ("appearance_and_figure", "外貌身材"),
        ("story_plot", "故事剧情"),
        ("story_location", "情景场所"),
        ("sex_positions", "性交体位"),
    ]
}

struct SearchTagSection: Identifiable, Sendable {
    let key: String
    let title: String
    let options: [SearchFilterOption]

    var id: String { key }
}

struct SearchFilterOption: Decodable, Hashable, Identifiable, Sendable {
    let lang: SearchOptionLanguage?
    let name: String?
    let searchKey: String?

    var id: String {
        searchKey ?? displayName
    }

    var displayName: String {
        if let lang {
            let locale = Locale.preferredLanguages.first?.lowercased() ?? ""
            if locale.hasPrefix("zh-hans") || locale.contains("cn") {
                return lang.zhHans ?? lang.zhHant ?? lang.en ?? name ?? searchKey ?? ""
            }
            if locale.hasPrefix("en") {
                return lang.en ?? lang.zhHant ?? lang.zhHans ?? name ?? searchKey ?? ""
            }
            return lang.zhHant ?? lang.zhHans ?? lang.en ?? name ?? searchKey ?? ""
        }
        return name ?? searchKey ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case lang
        case name
        case searchKey = "search_key"
    }
}

struct SearchOptionLanguage: Decodable, Hashable, Sendable {
    let zhHans: String?
    let zhHant: String?
    let en: String?

    private enum CodingKeys: String, CodingKey {
        case zhHans = "zh-rCN"
        case zhHant = "zh-rTW"
        case en
    }
}

struct SearchFilterState: Equatable {
    var genre: SearchFilterOption?
    var sort: SearchFilterOption?
    var duration: SearchFilterOption?
    var releaseDate: SearchFilterOption?
    var broad = false
    var tags: Set<SearchFilterOption> = []
    var brands: Set<SearchFilterOption> = []

    var activeCount: Int {
        var count = 0
        if genre?.searchKey?.isEmpty == false, genre?.searchKey != "全部" { count += 1 }
        if sort?.searchKey?.isEmpty == false { count += 1 }
        if duration?.searchKey?.isEmpty == false { count += 1 }
        if releaseDate?.searchKey?.isEmpty == false { count += 1 }
        if !tags.isEmpty { count += tags.count }
        if !brands.isEmpty { count += brands.count }
        if broad { count += 1 }
        return count
    }

    var hasActiveFilters: Bool {
        activeCount > 0
    }

    var selectedTagKeys: [String] {
        tags.compactMap(\.searchKey).filter { !$0.isEmpty }.sorted()
    }

    var selectedBrandKeys: [String] {
        brands.compactMap(\.searchKey).filter { !$0.isEmpty }.sorted()
    }

    var summaryItems: [String] {
        var items: [String] = []
        if let genre, let key = genre.searchKey, !key.isEmpty, key != "全部" {
            items.append(String(format: String(localized: "search.summary.genre"), genre.displayName))
        }
        if let sort, sort.searchKey?.isEmpty == false {
            items.append(String(format: String(localized: "search.summary.sort"), sort.displayName))
        }
        if let releaseDate, releaseDate.searchKey?.isEmpty == false {
            items.append(String(format: String(localized: "search.summary.release_date"), releaseDate.displayName))
        }
        if let duration, duration.searchKey?.isEmpty == false {
            items.append(String(format: String(localized: "search.summary.duration"), duration.displayName))
        }
        if !tags.isEmpty {
            // Show the actual tag names (joined), not just a count, so the
            // search summary / history reads e.g. "标签: 巨乳, 制服" instead
            // of "标签: 2".
            let names = tags.map(\.displayName).filter { !$0.isEmpty }.sorted()
            if !names.isEmpty {
                items.append(String(format: String(localized: "search.summary.tags"), names.joined(separator: ", ")))
            }
        }
        if !brands.isEmpty {
            let names = brands.map(\.displayName).filter { !$0.isEmpty }.sorted()
            if !names.isEmpty {
                items.append(String(format: String(localized: "search.summary.brands"), names.joined(separator: ", ")))
            }
        }
        if broad {
            items.append(String(localized: "search.summary.broad"))
        }
        return items
    }

    mutating func reset() {
        genre = nil
        sort = nil
        duration = nil
        releaseDate = nil
        broad = false
        tags = []
        brands = []
    }
}

extension SearchFilterState {
    static func homeSection(key: String, catalog: SearchOptionCatalog) -> SearchFilterState {
        var state = SearchFilterState()
        switch key {
        case "latestRelease":
            state.sort = catalog.sortOptions.firstSearchKey("最新上市")
        case "latestHanime":
            state.sort = catalog.sortOptions.firstSearchKey("最新上傳")
        case "watchingNow":
            state.sort = catalog.sortOptions.firstSearchKey("他們在看")
        case "ecchiAnime":
            state.genre = catalog.genres.firstSearchKey("裏番")
        case "shortEpisodeAnime":
            state.genre = catalog.genres.firstSearchKey("泡麵番")
        case "motionAnime":
            state.genre = catalog.genres.firstSearchKey("Motion Anime")
        case "threeDCG":
            state.genre = catalog.genres.firstSearchKey("3DCG")
        case "twoPointFiveDAnime":
            state.genre = catalog.genres.firstSearchKey("2.5D")
        case "twoDAnime":
            state.genre = catalog.genres.firstSearchKey("2D動畫")
        case "aiGenerated":
            state.genre = catalog.genres.firstSearchKey("AI生成")
        case "mmd":
            state.genre = catalog.genres.firstSearchKey("MMD")
        case "cosplay":
            state.genre = catalog.genres.firstSearchKey("Cosplay")
        default:
            break
        }
        return state
    }
}

private extension [SearchFilterOption] {
    func firstSearchKey(_ searchKey: String) -> SearchFilterOption? {
        first { $0.searchKey == searchKey }
    }
}

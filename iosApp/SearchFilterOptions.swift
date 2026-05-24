import Foundation

struct SearchOptionCatalog {
    let genres: [SearchFilterOption]
    let sortOptions: [SearchFilterOption]
    let durations: [SearchFilterOption]
    let releaseDates: [SearchFilterOption]
    let brands: [SearchFilterOption]
    let tagSections: [SearchTagSection]

    static let shared = SearchOptionCatalog()

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

struct SearchTagSection: Identifiable {
    let key: String
    let title: String
    let options: [SearchFilterOption]

    var id: String { key }
}

struct SearchFilterOption: Decodable, Hashable, Identifiable {
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

struct SearchOptionLanguage: Decodable, Hashable {
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
            items.append("类型: \(genre.displayName)")
        }
        if let sort, sort.searchKey?.isEmpty == false {
            items.append("排序: \(sort.displayName)")
        }
        if let releaseDate, releaseDate.searchKey?.isEmpty == false {
            items.append("日期: \(releaseDate.displayName)")
        }
        if let duration, duration.searchKey?.isEmpty == false {
            items.append("时长: \(duration.displayName)")
        }
        if !tags.isEmpty {
            items.append("标签: \(tags.count)")
        }
        if !brands.isEmpty {
            items.append("品牌: \(brands.count)")
        }
        if broad {
            items.append("模糊")
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

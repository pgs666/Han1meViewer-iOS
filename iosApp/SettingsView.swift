import SwiftUI
import Han1meShared

struct SettingsView: View {
    private let environment: SharedAppEnvironment

    @State private var activeConfirmation: SettingsConfirmation?
    @State private var resultMessage: String?
    @State private var cacheSizeText = "计算中…"
    @State private var crashReportSummary = CrashReporter.latestReportSummary()

    // Preferences
    @State private var defaultVideoQuality: String = "1080P"
    @State private var videoLanguage: String = "cht"
    @State private var longPressSpeed: Float = 2.0
    @State private var allowResumePlayback: Bool = true
    @State private var showPlayedIndicator: Bool = true
    @State private var showBottomProgress: Bool = true

    init(environment: SharedAppEnvironment) {
        self.environment = environment
    }

    var body: some View {
        List {
            playbackSettingsSection
            uiSection
            appInfoSection
            localDataSection
            cacheSection
            crashReportSection
        }
        .navigationTitle("设置")
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog(
            activeConfirmation?.title ?? "",
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            if let activeConfirmation {
                Button(activeConfirmation.actionTitle, role: .destructive) {
                    perform(activeConfirmation)
                }
            }
            Button("取消", role: .cancel) {
                activeConfirmation = nil
            }
        }
        .alert("已完成", isPresented: resultBinding) {
            Button("好", role: .cancel) {
                resultMessage = nil
            }
        } message: {
            Text(resultMessage ?? "")
        }
        .task {
            await refreshCacheSize()
            loadPreferences()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var playbackSettingsSection: some View {
        Section("播放设置") {
            Picker("默认画质", selection: $defaultVideoQuality) {
                Text("2160P").tag("2160P")
                Text("1440P").tag("1440P")
                Text("1080P").tag("1080P")
                Text("720P").tag("720P")
                Text("480P").tag("480P")
                Text("360P").tag("360P")
            }
            .onValueChange(of: defaultVideoQuality) { newValue in
                environment.preferences().defaultVideoQuality.set(value: newValue)
            }

            Picker("字幕语言", selection: $videoLanguage) {
                Text("繁体中文").tag("cht")
                Text("简体中文").tag("chs")
                Text("日文").tag("jp")
                Text("英文").tag("en")
            }
            .onValueChange(of: videoLanguage) { newValue in
                environment.preferences().videoLanguage.set(value: newValue)
            }

            HStack {
                Text("长按倍速")
                Spacer()
                Text(String(format: "%.2fx", longPressSpeed))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $longPressSpeed, in: 1.0...3.0, step: 0.25) {
                Text("长按倍速")
            } minimumValueLabel: {
                Text("1.0x")
                    .font(.caption)
            } maximumValueLabel: {
                Text("3.0x")
                    .font(.caption)
            }
            .onValueChange(of: longPressSpeed) { newValue in
                environment.preferences().longPressSpeedTimes.set(value: newValue)
            }
            Text("按住屏幕时切换到该倍速，松手恢复。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("自动恢复播放进度", isOn: $allowResumePlayback)
                .onValueChange(of: allowResumePlayback) { newValue in
                    environment.preferences().allowResumePlayback.set(value: newValue)
                }
        }
    }

    @ViewBuilder
    private var uiSection: some View {
        Section("界面") {
            Toggle("显示已看标记", isOn: $showPlayedIndicator)
                .onValueChange(of: showPlayedIndicator) { newValue in
                    environment.preferences().showPlayedIndicator.set(value: newValue)
                }

            Toggle("底部进度条", isOn: $showBottomProgress)
                .onValueChange(of: showBottomProgress) { newValue in
                    environment.preferences().showBottomProgress.set(value: newValue)
                }
        }
    }

    @ViewBuilder
    private var appInfoSection: some View {
        Section("应用") {
            SettingsInfoRow(title: "版本", value: appVersion)
            if let repositoryURL = URL(string: "https://github.com/pgs666/Han1meViewer-iOS") {
                Link(destination: repositoryURL) {
                    SettingsNavigationRow(title: "项目仓库", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            if let siteURL = URL(string: "https://hanime1.me") {
                Link(destination: siteURL) {
                    SettingsNavigationRow(title: "打开网站", systemImage: "safari")
                }
            }
        }
    }

    @ViewBuilder
    private var localDataSection: some View {
        Section {
            localDataActions
        } header: {
            Text("本地数据")
        } footer: {
            Text("这里只清除 iOS 本地数据，不会修改网站账号里的在线记录。")
        }
    }

    @ViewBuilder
    private var cacheSection: some View {
        Section {
            Button(role: .destructive) {
                Task {
                    await refreshCacheSize()
                }
                activeConfirmation = .clearCache
            } label: {
                SettingsNavigationRow(title: "清除缓存（\(cacheSizeText)）", systemImage: "trash")
            }
        } header: {
            Text("缓存")
        } footer: {
            Text("缓存包含图片和网络临时文件；清除后不会退出登录，也不会删除历史记录。")
        }
    }

    @ViewBuilder
    private var crashReportSection: some View {
        if let crashReportSummary {
            Section {
                SettingsInfoRow(title: "上次异常", value: crashReportSummary)
            } header: {
                Text("崩溃报告")
            } footer: {
                Text("如果应用上次异常退出，这里会显示最后记录的异常摘要，帮助定位上次异常退出。")
            }
        }
    }

    // MARK: - Preferences

    private func loadPreferences() {
        let prefs = environment.preferences()
        defaultVideoQuality = prefs.defaultVideoQuality.get()
        videoLanguage = prefs.videoLanguage.get()
        longPressSpeed = prefs.longPressSpeedTimes.get()
        allowResumePlayback = prefs.allowResumePlayback.get()
        showPlayedIndicator = prefs.showPlayedIndicator.get()
        showBottomProgress = prefs.showBottomProgress.get()
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [version, build.map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    @ViewBuilder
    private var localDataActions: some View {
        Button(role: .destructive) {
            activeConfirmation = .clearSearchHistory
        } label: {
            SettingsNavigationRow(title: "清除搜索历史", systemImage: "magnifyingglass")
        }

        Button(role: .destructive) {
            activeConfirmation = .clearWatchHistory
        } label: {
            SettingsNavigationRow(title: "清除本地观看历史", systemImage: "clock")
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { activeConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    activeConfirmation = nil
                }
            }
        )
    }

    private var resultBinding: Binding<Bool> {
        Binding(
            get: { resultMessage != nil },
            set: { isPresented in
                if !isPresented {
                    resultMessage = nil
                }
            }
        )
    }

    private func perform(_ confirmation: SettingsConfirmation) {
        switch confirmation {
        case .clearSearchHistory:
            _ = environment.searchFeature().clearHistory()
            resultMessage = "搜索历史已清除。"
        case .clearWatchHistory:
            _ = environment.watchHistoryFeature().clear()
            resultMessage = "本地观看历史已清除。"
        case .clearCache:
            let oldSize = cacheSizeText
            Task {
                await CacheStorage.clearAsync()
                await refreshCacheSize()
                resultMessage = "已清除 \(oldSize) 缓存。"
            }
        }
        activeConfirmation = nil
    }

    private func refreshCacheSize() async {
        cacheSizeText = await CacheStorage.formattedSizeAsync()
    }
}

private enum SettingsConfirmation: Identifiable {
    case clearSearchHistory
    case clearWatchHistory
    case clearCache

    var id: String {
        switch self {
        case .clearSearchHistory:
            return "clearSearchHistory"
        case .clearWatchHistory:
            return "clearWatchHistory"
        case .clearCache:
            return "clearCache"
        }
    }

    var title: String {
        switch self {
        case .clearSearchHistory:
            return "确定清除搜索历史？"
        case .clearWatchHistory:
            return "确定清除本地观看历史？"
        case .clearCache:
            return "确定清除缓存？"
        }
    }

    var actionTitle: String {
        switch self {
        case .clearSearchHistory:
            return "清除搜索历史"
        case .clearWatchHistory:
            return "清除本地观看历史"
        case .clearCache:
            return "清除缓存"
        }
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.primary)
    }
}

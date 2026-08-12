import SwiftUI
import Han1meShared
import Darwin

struct SettingsView: View {
    private let environment: SharedAppEnvironment

    @State private var activeConfirmation: SettingsConfirmation?
    @State private var resultMessage: String?
    @State private var cacheSizeText = String(localized: "计算中…")
    @State private var crashReportSummary = CrashReporter.latestReportSummary()
    @AppStorage(AppLogger.enabledKey) private var diagnosticLoggingEnabled = true
    @State private var logSizeText = "—"
    @State private var selectedDomain = AppDomain.usesCustomMirror
        ? "custom:\(AppDomain.currentHomeURL)"
        : AppDomain.selectedPresetURL
    @State private var pendingSiteChange: PendingSiteChange?
    @State private var showCustomMirrorWarning = false

    // Preferences. Seeded with the REAL stored values in init() so the
    // controls render at their actual positions on first frame. Previously
    // these held hard-coded defaults and were overwritten by loadPreferences()
    // from .task AFTER `await refreshCacheSize()` — that late batch of ~9
    // @State writes landed inside the push transition window, which made
    // SwiftUI drop the push animation (and showed the sliders visibly jump
    // from default to real value).
    @State private var defaultVideoQuality: String
    @State private var videoLanguage: String
    @State private var longPressSpeed: Float
    @State private var allowResumePlayback: Bool
    @State private var forcePortraitFullscreenForVerticalVideos: Bool
    @State private var autoPlayOnEnter: Bool
    @State private var maxConcurrentDownloads: Int
    @State private var showPlayedIndicator: Bool
    @State private var showBottomProgress: Bool

    init(environment: SharedAppEnvironment) {
        self.environment = environment
        let prefs = environment.preferences()
        _defaultVideoQuality = State(initialValue: prefs.defaultVideoQuality.get())
        _videoLanguage = State(initialValue: prefs.videoLanguage.get())
        _longPressSpeed = State(initialValue: prefs.longPressSpeedTimes.get())
        _allowResumePlayback = State(initialValue: prefs.allowResumePlayback.get())
        _forcePortraitFullscreenForVerticalVideos = State(initialValue: prefs.forcePortraitFullscreenForVerticalVideos.get())
        _autoPlayOnEnter = State(initialValue: prefs.autoPlayOnEnter.get())
        _maxConcurrentDownloads = State(initialValue: Int(prefs.maxConcurrentDownloads.get()))
        _showPlayedIndicator = State(initialValue: prefs.showPlayedIndicator.get())
        _showBottomProgress = State(initialValue: prefs.showBottomProgress.get())
    }

    var body: some View {
        List {
            playbackSettingsSection
            uiSection
            downloadSettingsSection
            networkSettingsSection
            appInfoSection
            localDataSection
            cacheSection
            diagnosticsSection
            crashReportSection
        }
        .navigationTitle("设置")
        .hidesTabBarOnAppear()
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
        .alert("确认切换站点？", isPresented: domainSwitchBinding) {
            Button("取消", role: .cancel, action: cancelDomainSwitch)
            Button("切换并退出", role: .destructive, action: confirmDomainSwitch)
        } message: {
            if let pendingSiteChange {
                Text("目标站点：") +
                    Text(verbatim: pendingSiteChange.displayURL) +
                    Text(verbatim: "\n") +
                    Text("确认后应用将自动退出，请重新打开应用以使用新站点。")
            }
        }
        .alert("自定义镜像站警告", isPresented: $showCustomMirrorWarning) {
            Button("取消", role: .cancel, action: cancelDomainSwitch)
            Button("继续", role: .destructive) {
                showCustomMirrorWarning = false
            }
        } message: {
            Text("自定义镜像站不一定可用，也可能与主站存在差异。镜像站可读取登录凭据及 Cookie，请只使用可信地址。")
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
            refreshLogSize()
        }
    }

    private func refreshLogSize() {
        let bytes = AppLogger.totalSizeBytes()
        logSizeText = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
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
                Text("繁体中文").tag("zht")
                Text("简体中文").tag("zhs")
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

            Toggle("竖屏视频不强制横屏", isOn: $forcePortraitFullscreenForVerticalVideos)
                .onValueChange(of: forcePortraitFullscreenForVerticalVideos) { newValue in
                    environment.preferences().forcePortraitFullscreenForVerticalVideos.set(value: newValue)
                }
            Text("打开后，竖屏视频进入全屏时保持竖屏，不旋转设备；横屏视频不受影响。关闭则始终强制横屏。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("打开视频时自动播放", isOn: $autoPlayOnEnter)
                .onValueChange(of: autoPlayOnEnter) { newValue in
                    environment.preferences().autoPlayOnEnter.set(value: newValue)
                }
            Text("关闭后，进入视频详情页不会自动开始播放，需要手动点击播放按钮。")
                .font(.caption)
                .foregroundStyle(.secondary)
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

            NavigationLink {
                HomeSectionOrderView()
            } label: {
                SettingsNavigationRow(title: "首页栏目排序", systemImage: "list.number")
            }
        }
    }

    @ViewBuilder
    private var downloadSettingsSection: some View {
        Section("下载") {
            Stepper(value: $maxConcurrentDownloads, in: 1...5) {
                HStack {
                    Text("最大同时下载数")
                    Spacer()
                    Text("\(maxConcurrentDownloads)")
                        .foregroundStyle(.secondary)
                }
            }
            .onValueChange(of: maxConcurrentDownloads) { newValue in
                environment.preferences().maxConcurrentDownloads.set(value: Int32(newValue))
            }
            Text("同时进行的下载任务数量上限，超出的会排队等待。")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            if let siteURL = URL(string: AppDomain.currentHomeURL) {
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
    private var networkSettingsSection: some View {
        Section {
            Picker("站点域名", selection: $selectedDomain) {
                ForEach(AppDomain.options, id: \.url) { option in
                    (Text(verbatim: option.host) + Text(verbatim: " (") + Text(option.suffix) + Text(verbatim: ")"))
                        .tag(option.url)
                }
                if AppDomain.usesCustomMirror {
                    (Text(verbatim: AppDomain.displayHost(for: AppDomain.currentHomeURL)) +
                     Text(verbatim: " (") + Text("自定义") + Text(verbatim: ")"))
                        .tag("custom:\(AppDomain.currentHomeURL)")
                }
            }
            .onValueChange(of: selectedDomain) { newValue in
                requestDomainSwitch(to: newValue)
            }

            NavigationLink {
                CustomMirrorView(
                    initialConfiguration: CustomMirrorConfiguration(
                        enabled: AppDomain.usesCustomMirror,
                        homeURL: AppDomain.customMirrorSite,
                        appendPath: AppDomain.appendsCustomMirrorPath
                    ),
                    onSave: requestCustomMirrorSwitch
                )
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    SettingsNavigationRow(title: "自定义镜像站", systemImage: "network")
                    if AppDomain.usesCustomMirror {
                        Text(verbatim: AppDomain.customMirrorSite)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        } header: {
            Text("网络")
        } footer: {
            Text("选择新站点后会先请求确认；确认后应用将自动退出，重新打开即可生效。")
        }
    }

    private func requestDomainSwitch(to newDomain: String) {
        let currentSelection = AppDomain.usesCustomMirror
            ? "custom:\(AppDomain.currentHomeURL)"
            : AppDomain.selectedPresetURL
        guard newDomain != currentSelection else { return }
        selectedDomain = currentSelection
        pendingSiteChange = .preset(newDomain)
    }

    private func requestCustomMirrorSwitch(_ configuration: CustomMirrorConfiguration) {
        let current = CustomMirrorConfiguration(
            enabled: AppDomain.usesCustomMirror,
            homeURL: AppDomain.customMirrorSite,
            appendPath: AppDomain.appendsCustomMirrorPath
        )
        guard configuration != current else { return }
        showCustomMirrorWarning = configuration.enabled
        pendingSiteChange = .custom(configuration)
    }

    private func cancelDomainSwitch() {
        selectedDomain = AppDomain.usesCustomMirror
            ? "custom:\(AppDomain.currentHomeURL)"
            : AppDomain.selectedPresetURL
        pendingSiteChange = nil
        showCustomMirrorWarning = false
    }

    private func confirmDomainSwitch() {
        guard let pendingSiteChange else { return }
        switch pendingSiteChange {
        case .preset(let url):
            AppDomain.applyPreset(url)
        case .custom(let configuration):
            AppDomain.applyCustomMirror(
                url: configuration.homeURL,
                appendPath: configuration.appendPath,
                enabled: configuration.enabled
            )
        }
        UserDefaults.standard.synchronize()
        exit(EXIT_SUCCESS)
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section {
            Toggle("记录诊断日志", isOn: $diagnosticLoggingEnabled)

            HStack {
                Text("日志大小")
                Spacer()
                Text(logSizeText)
                    .foregroundStyle(.secondary)
            }

            ShareLink(item: AppLogger.logsDirectory()) {
                SettingsNavigationRow(title: "导出 / 分享日志", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                AppLogger.clear()
                refreshLogSize()
            } label: {
                Text("清除日志")
            }
        } header: {
            Text("诊断日志")
        } footer: {
            Text("记录页面跳转与关键操作（已自动脱敏，不含账号、Cookie 等敏感信息），日志按大小滚动并自动清理。日志文件也可在「文件」App → 我的 iPhone/iPad → Han1meViewer → Logs 中找到，遇到问题时可导出并附到 GitHub issue。")
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

    private var domainSwitchBinding: Binding<Bool> {
        Binding(
            get: { pendingSiteChange != nil && !showCustomMirrorWarning },
            set: { isPresented in
                if !isPresented {
                    cancelDomainSwitch()
                }
            }
        )
    }

    private func perform(_ confirmation: SettingsConfirmation) {
        switch confirmation {
        case .clearSearchHistory:
            _ = environment.searchFeature().clearHistory()
            resultMessage = String(localized: "搜索历史已清除。")
        case .clearWatchHistory:
            _ = environment.watchHistoryFeature().clear()
            resultMessage = String(localized: "本地观看历史已清除。")
        case .clearCache:
            let oldSize = cacheSizeText
            Task {
                await CacheStorage.clearAsync()
                await refreshCacheSize()
                resultMessage = String(localized: "已清除 \(oldSize) 缓存。")
            }
        }
        activeConfirmation = nil
    }

    private func refreshCacheSize() async {
        cacheSizeText = await CacheStorage.formattedSizeAsync()
    }
}

private struct CustomMirrorView: View {
    let onSave: (CustomMirrorConfiguration) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var enabled: Bool
    @State private var draft: String
    @State private var appendPath: Bool
    @State private var validationMessage: String?
    @State private var testResult: CustomMirrorTestResult?
    @State private var isTesting = false

    init(
        initialConfiguration: CustomMirrorConfiguration,
        onSave: @escaping (CustomMirrorConfiguration) -> Void
    ) {
        self.onSave = onSave
        _enabled = State(initialValue: initialConfiguration.enabled)
        _draft = State(initialValue: initialConfiguration.homeURL)
        _appendPath = State(initialValue: initialConfiguration.appendPath)
    }

    var body: some View {
        Form {
            Section {
                Toggle("启用自定义镜像站", isOn: $enabled)

                TextField("例如 https://mirror.example.com/enter", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("镜像站地址")
            } footer: {
                Text("请输入与主站结构相同、直达首页的 HTTPS 地址。支持根域名或 /enter 等首页路径；首页会按输入原样请求。")
            }

            Section("其他接口路径") {
                Picker("接口路径", selection: $appendPath) {
                    Text("跟随首页目录").tag(true)
                    Text("使用根域名").tag(false)
                }
                .pickerStyle(.inline)

                Text(appendPath
                     ? "例如：https://example.com/enter/search"
                     : "例如：https://example.com/search；首页仍按输入地址请求。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        if isTesting { ProgressView() }
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)

                if let testResult {
                    Text(testResult.message)
                        .font(.caption)
                        .foregroundStyle(testResult.succeeded ? Color.green : Color.orange)
                }

                Button("保存并切换", action: save)
                    .frame(maxWidth: .infinity)
                    .disabled(enabled && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("自定义镜像站")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnAppear()
    }

    private func save() {
        let normalized = AppDomain.normalizedCustomMirrorURL(from: draft)
        guard !enabled || normalized != nil else {
            validationMessage = String(localized: "请输入有效且直达首页的 HTTPS 地址。")
            return
        }
        onSave(CustomMirrorConfiguration(
            enabled: enabled,
            homeURL: normalized ?? "",
            appendPath: appendPath
        ))
        dismiss()
    }

    private func testConnection() {
        guard let normalized = AppDomain.normalizedCustomMirrorURL(from: draft) else {
            validationMessage = String(localized: "请输入有效且直达首页的 HTTPS 地址。")
            return
        }
        validationMessage = nil
        testResult = nil
        isTesting = true
        Task {
            testResult = await CustomMirrorTester.test(homeURL: normalized, appendPath: appendPath)
            isTesting = false
        }
    }
}

private struct CustomMirrorConfiguration: Equatable {
    let enabled: Bool
    let homeURL: String
    let appendPath: Bool
}

private enum PendingSiteChange {
    case preset(String)
    case custom(CustomMirrorConfiguration)

    var displayURL: String {
        switch self {
        case .preset(let url): return url
        case .custom(let configuration):
            return configuration.enabled ? configuration.homeURL : AppDomain.selectedPresetURL
        }
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
            return String(localized: "确定清除搜索历史？")
        case .clearWatchHistory:
            return String(localized: "确定清除本地观看历史？")
        case .clearCache:
            return String(localized: "确定清除缓存？")
        }
    }

    var actionTitle: String {
        switch self {
        case .clearSearchHistory:
            return String(localized: "清除搜索历史")
        case .clearWatchHistory:
            return String(localized: "清除本地观看历史")
        case .clearCache:
            return String(localized: "清除缓存")
        }
    }
}

private struct SettingsInfoRow: View {
    let title: LocalizedStringKey
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
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.primary)
    }
}

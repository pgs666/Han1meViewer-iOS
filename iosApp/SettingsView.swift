import SwiftUI
import Han1meShared

struct SettingsView: View {
    private let environment: SharedAppEnvironment

    @State private var activeConfirmation: SettingsConfirmation?
    @State private var resultMessage: String?
    @State private var cacheSizeText = "计算中…"
    @State private var crashReportSummary = CrashReporter.latestReportSummary()

    init(environment: SharedAppEnvironment) {
        self.environment = environment
    }

    var body: some View {
        List {
            Section("应用") {
                SettingsInfoRow(title: "版本", value: appVersion)
                Link(destination: URL(string: "https://github.com/pgs666/Han1meViewer-iOS")!) {
                    SettingsNavigationRow(title: "项目仓库", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://hanime1.me")!) {
                    SettingsNavigationRow(title: "打开网站", systemImage: "safari")
                }
            }

            Section {
                localDataActions
            } header: {
                Text("本地数据")
            } footer: {
                Text("这里只清除 iOS 本地数据，不会修改网站账号里的在线记录。")
            }

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

            if let crashReportSummary {
                Section {
                    Text(crashReportSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button(role: .destructive) {
                        CrashReporter.clearReports()
                        self.crashReportSummary = nil
                        resultMessage = "崩溃报告已清除。"
                    } label: {
                        SettingsNavigationRow(title: "清除崩溃报告", systemImage: "xmark.bin")
                    }
                } header: {
                    Text("崩溃报告")
                } footer: {
                    Text("仅保存在本机，用于复现和定位上次异常退出。")
                }
            }
        }
        .navigationTitle("设置")
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
        }
    }

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

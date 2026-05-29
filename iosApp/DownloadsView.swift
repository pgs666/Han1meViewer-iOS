import SwiftUI
import Han1meShared

/// Download manager screen pushed from MineView. Lists every download
/// (queued / downloading / paused / finished / failed) with progress,
/// per-item pause/resume, swipe-to-delete, and tap-to-play for finished
/// items. Backed by DownloadManager.shared (observable).
struct DownloadsView: View {
    let environment: SharedAppEnvironment
    @ObservedObject private var manager = DownloadManager.shared

    init(environment: SharedAppEnvironment) {
        self.environment = environment
    }

    var body: some View {
        Group {
            if manager.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("下载")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnAppear()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无下载")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(manager.items) { item in
                row(item)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func row(_ item: DownloadUIItem) -> some View {
        let content = DownloadRow(item: item) {
            // Primary tap action depends on state.
            switch item.state {
            case .downloading, .queued:
                manager.pause(item)
            case .paused, .failed:
                manager.resume(item)
            case .finished:
                break
            }
        }

        if item.isFinished {
            NavigationLink {
                LocalVideoPlayerView(
                    videoCode: item.videoCode,
                    quality: item.quality,
                    title: item.title,
                    fileURL: item.localFileURL
                )
            } label: {
                content
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    manager.delete(item)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        } else {
            content
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        manager.delete(item)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
        }
    }
}

private struct DownloadRow: View {
    let item: DownloadUIItem
    /// Tap on the trailing status control (pause/resume). Finished items
    /// don't use it (the whole row becomes a NavigationLink instead).
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CachedRemoteImage(urlString: item.coverUrl, resizeWidth: 96)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .lineLimit(2)
                    .font(.subheadline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !item.isFinished {
                    ProgressView(value: item.progress)
                        .tint(item.state == .failed ? .red : .accentColor)
                }
            }

            if !item.isFinished {
                Button(action: onToggle) {
                    Image(systemName: toggleIcon)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var toggleIcon: String {
        switch item.state {
        case .downloading, .queued: return "pause.circle"
        case .paused, .failed:      return "arrow.clockwise.circle"
        case .finished:             return "checkmark.circle.fill"
        }
    }

    private var statusLine: String {
        let pct = Int(item.progress * 100)
        switch item.state {
        case .queued:      return "排队中 · \(item.quality)"
        case .downloading: return "下载中 \(pct)% · \(item.quality)"
        case .paused:      return "已暂停 \(pct)% · \(item.quality)"
        case .finished:    return "已完成 · \(item.quality)"
        case .failed:      return "下载失败，点击重试 · \(item.quality)"
        }
    }
}

import SwiftUI
import UIKit
import Han1meShared

final class VideoDetailCommentTableView: UITableView {
    var playerCollapseOffset: CGFloat = 0
}

struct CommentView: View {
    @ObservedObject private var viewModel: CommentViewModel
    private let onOverlayActivityChanged: (Bool) -> Void
    private let contentBottomPadding: CGFloat
    private let collapseDistance: CGFloat
    private let collapseOffset: CGFloat
    private let onScrollOffsetChange: (CGFloat) -> Void
    @State private var replyTarget: CommentRow?
    @State private var replyText = ""
    @State private var reportTarget: CommentRow?
    @State private var repliesTarget: CommentRow?

    init(
        viewModel: CommentViewModel,
        contentBottomPadding: CGFloat = 24,
        collapseDistance: CGFloat = 0,
        collapseOffset: CGFloat = 0,
        onScrollOffsetChange: @escaping (CGFloat) -> Void = { _ in },
        onOverlayActivityChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.contentBottomPadding = contentBottomPadding
        self.collapseDistance = collapseDistance
        self.collapseOffset = collapseOffset
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onOverlayActivityChanged = onOverlayActivityChanged
    }

    var body: some View {
        CommentTableView(
            state: viewModel.state,
            sortMode: viewModel.sortMode,
            sortedComments: viewModel.sortedComments,
            runningActionIDs: viewModel.runningActionIDs,
            contentBottomPadding: contentBottomPadding,
            collapseDistance: collapseDistance,
            collapseOffset: collapseOffset,
            onSortModeChange: { viewModel.changeSortMode($0) },
            onRefresh: { viewModel.load() },
            onRetry: { viewModel.load() },
            onReply: { comment in
                replyText = "@\(comment.username) "
                replyTarget = comment
            },
            onShowReplies: { comment in
                repliesTarget = comment
            },
            onLike: { comment in
                viewModel.like(comment: comment, isPositive: true)
            },
            onDislike: { comment in
                viewModel.like(comment: comment, isPositive: false)
            },
            onReport: { comment in
                reportTarget = comment
            },
            onScrollOffsetChange: onScrollOffsetChange
        )
        .task {
            viewModel.loadIfNeeded()
        }
        .onValueChange(of: replyTarget?.id) { _ in
            notifyOverlayActivityChanged()
        }
        .onValueChange(of: repliesTarget?.id) { _ in
            notifyOverlayActivityChanged()
        }
        .onDisappear {
            onOverlayActivityChanged(false)
        }
        .alert("提示", isPresented: actionMessageBinding) {
            Button("好", role: .cancel) {
                viewModel.actionMessage = nil
            }
        } message: {
            Text(viewModel.actionMessage ?? "")
        }
        .sheet(item: $replyTarget) { comment in
            CommentTextSheet(
                title: "回复 \(comment.username)",
                text: $replyText,
                placeholder: "输入回复",
                submitTitle: "回复",
                onCancel: {
                    replyTarget = nil
                    replyText = ""
                },
                onSubmit: {
                    viewModel.postReply(to: comment, text: replyText)
                    replyTarget = nil
                    replyText = ""
                }
            )
        }
        .sheet(item: $repliesTarget) { comment in
            CommentRepliesSheet(
                comment: comment,
                viewModel: viewModel
            ) { reply in
                    replyText = "@\(reply.username) "
                    replyTarget = reply
            }
        }
        .confirmationDialog("举报原因", isPresented: reportDialogBinding, titleVisibility: .visible) {
            ForEach(viewModel.reportReasons) { reason in
                Button(reason.title) {
                    if let reportTarget {
                        viewModel.report(comment: reportTarget, reason: reason)
                    }
                    reportTarget = nil
                }
            }
            Button("取消", role: .cancel) {
                reportTarget = nil
            }
        }
    }

    private var actionMessageBinding: Binding<Bool> {
        Binding(
            get: { viewModel.actionMessage != nil },
            set: { if !$0 { viewModel.actionMessage = nil } }
        )
    }

    private var reportDialogBinding: Binding<Bool> {
        Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        )
    }

    private func notifyOverlayActivityChanged() {
        onOverlayActivityChanged(replyTarget != nil || repliesTarget != nil)
    }
}

private struct CommentTableView: UIViewRepresentable {
    let state: CommentViewModel.State
    let sortMode: CommentViewModel.SortMode
    let sortedComments: [CommentRow]
    let runningActionIDs: Set<String>
    let contentBottomPadding: CGFloat
    let collapseDistance: CGFloat
    let collapseOffset: CGFloat
    let onSortModeChange: (CommentViewModel.SortMode) -> Void
    let onRefresh: () -> Void
    let onRetry: () -> Void
    let onReply: (CommentRow) -> Void
    let onShowReplies: (CommentRow) -> Void
    let onLike: (CommentRow) -> Void
    let onDislike: (CommentRow) -> Void
    let onReport: (CommentRow) -> Void
    let onScrollOffsetChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITableView {
        let tableView = VideoDetailCommentTableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.keyboardDismissMode = .interactive
        tableView.bounces = false
        tableView.alwaysBounceVertical = false
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Coordinator.cellReuseIdentifier)
        return tableView
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.rows = rows
        context.coordinator.syncCollapseDistance(with: self, tableView: tableView)
        tableView.contentInset.bottom = contentBottomPadding + collapseDistance + 1
        tableView.verticalScrollIndicatorInsets.bottom = contentBottomPadding
        tableView.reloadData()
    }

    private var rows: [Row] {
        var rows: [Row] = [.header]
        switch state {
        case .idle, .loading:
            rows.append(.loading)
        case .failed(let message):
            rows.append(.failed(message))
        case .loaded:
            if sortedComments.isEmpty {
                rows.append(.empty)
            } else {
                rows.append(contentsOf: sortedComments.map(Row.comment))
                rows.append(.footer)
            }
        }
        return rows
    }

    enum Row {
        case header
        case loading
        case failed(String)
        case empty
        case comment(CommentRow)
        case footer
    }

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        static let cellReuseIdentifier = "CommentTableCell"

        var parent: CommentTableView
        var rows: [Row] = []
        private var reportedContentOffsetY: CGFloat = 0
        private var appliedContentOffsetY: CGFloat = 0
        private var isApplyingContentOffset = false

        init(parent: CommentTableView) {
            self.parent = parent
        }

        func syncCollapseDistance(with parent: CommentTableView, tableView: UITableView) {
            let physicalOffsetY = max(0, tableView.contentOffset.y)
            if reportedContentOffsetY <= 0, physicalOffsetY > 0 {
                reportedContentOffsetY = physicalOffsetY + max(parent.collapseOffset, 0)
            }
            appliedContentOffsetY = tableView.contentOffset.y
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            rows.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            cell.contentConfiguration = UIHostingConfiguration {
                view(for: rows[indexPath.row])
            }
            .margins(.all, 0)
            return cell
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isApplyingContentOffset else { return }

            let observedContentOffsetY = scrollView.contentOffset.y
            let deltaY = observedContentOffsetY - appliedContentOffsetY
            guard abs(deltaY) > 0.01 else {
                parent.onScrollOffsetChange(reportedContentOffsetY)
                return
            }

            var targetContentOffsetY = observedContentOffsetY
            let currentCollapseOffset = (scrollView as? VideoDetailCommentTableView)?.playerCollapseOffset
                ?? parent.collapseOffset
            let remainingCollapseDistance = max(parent.collapseDistance - currentCollapseOffset, 0)
            if deltaY > 0, remainingCollapseDistance > 0.5 {
                let consumedByCollapse = min(deltaY, remainingCollapseDistance)
                targetContentOffsetY = appliedContentOffsetY + deltaY - consumedByCollapse
            } else if deltaY < 0, currentCollapseOffset > 0.5 {
                let consumedByExpansion = max(deltaY, -currentCollapseOffset)
                targetContentOffsetY = appliedContentOffsetY + deltaY - consumedByExpansion
            }

            reportedContentOffsetY = max(0, reportedContentOffsetY + deltaY)
            parent.onScrollOffsetChange(reportedContentOffsetY)

            if abs(scrollView.contentOffset.y - targetContentOffsetY) > 0.5 {
                isApplyingContentOffset = true
                scrollView.setContentOffset(
                    CGPoint(x: scrollView.contentOffset.x, y: targetContentOffsetY),
                    animated: false
                )
                isApplyingContentOffset = false
            }
            appliedContentOffsetY = targetContentOffsetY
        }

        @ViewBuilder
        private func view(for row: Row) -> some View {
            switch row {
            case .header:
                CommentHeaderView(
                    sortMode: parent.sortMode,
                    onSortModeChange: parent.onSortModeChange,
                    onRefresh: parent.onRefresh
                )
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 60)
                .padding(.horizontal, 16)
            case .failed(let message):
                CommentFailureView(message: message, onRetry: parent.onRetry)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 60)
            case .empty:
                CommentEmptyView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 60)
            case .comment(let comment):
                CommentRowView(
                    comment: comment,
                    isRunningLike: parent.runningActionIDs.contains("like-\(comment.id)"),
                    onReply: { self.parent.onReply(comment) },
                    onShowReplies: { self.parent.onShowReplies(comment) },
                    onLike: { self.parent.onLike(comment) },
                    onDislike: { self.parent.onDislike(comment) },
                    onReport: { self.parent.onReport(comment) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            case .footer:
                Text("comment.no_more")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }
}

private struct CommentHeaderView: View {
    let sortMode: CommentViewModel.SortMode
    let onSortModeChange: (CommentViewModel.SortMode) -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(CommentViewModel.SortMode.allCases) { mode in
                    Button {
                        onSortModeChange(mode)
                    } label: {
                        if mode == sortMode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                Label(sortMode.title, systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Spacer()

            TapOnlyControl {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct CommentFailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("评论加载失败")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TapOnlyControl {
                onRetry()
            } label: {
                Text("重试")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            CloudflareVerifyButton(errorMessage: message)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CommentEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无评论")
                .font(.headline)
            Text("成为第一个评论的人。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CommentRowView: View {
    let comment: CommentRow
    let isRunningLike: Bool
    let onReply: () -> Void
    let onShowReplies: () -> Void
    let onLike: () -> Void
    let onDislike: () -> Void
    let onReport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedRemoteImage(urlString: comment.avatarUrl, resizeWidth: comment.isChildComment ? 34 : 42)
                .frame(width: comment.isChildComment ? 34 : 42, height: comment.isChildComment ? 34 : 42)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.username)
                        .font(.subheadline.weight(.semibold))
                    Text(comment.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TapOnlyControl(action: onReport) {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(comment.content)
                    .font(.body)
                    .textSelection(.enabled)

                HStack(spacing: 14) {
                    TapOnlyControl(isDisabled: isRunningLike) {
                        onLike()
                    } label: {
                        Label("\(comment.thumbUp ?? 0)", systemImage: comment.likeCommentStatus ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }

                    TapOnlyControl(isDisabled: isRunningLike) {
                        onDislike()
                    } label: {
                        Image(systemName: comment.unlikeCommentStatus ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    }

                    TapOnlyControl(action: onReply) {
                        Text("回复")
                    }

                    if comment.hasMoreReplies {
                        TapOnlyControl(action: onShowReplies) {
                            Text("查看 \(comment.replyCount ?? 0) 条回复")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CommentRepliesSheet: View {
    @ObservedObject var viewModel: CommentViewModel
    let onReply: (CommentRow) -> Void

    @State private var state: RepliesState = .loading
    @State private var displayedComment: CommentRow
    @State private var reportTarget: CommentRow?

    init(
        comment: CommentRow,
        viewModel: CommentViewModel,
        onReply: @escaping (CommentRow) -> Void
    ) {
        self.viewModel = viewModel
        self.onReply = onReply
        _displayedComment = State(initialValue: comment)
    }

    var body: some View {
        CompatibleNavigationStack {
            content
                .navigationTitle("回复")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await load()
        }
        .confirmationDialog("举报原因", isPresented: reportDialogBinding, titleVisibility: .visible) {
            ForEach(viewModel.reportReasons) { reason in
                Button(reason.title) {
                    if let reportTarget {
                        viewModel.report(comment: reportTarget, reason: reason)
                    }
                    reportTarget = nil
                }
            }
            Button("取消", role: .cancel) {
                reportTarget = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Text("回复加载失败")
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                Button("重试") {
                    Task { await load() }
                }
                CloudflareVerifyButton(errorMessage: message)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let replies):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    CommentRowView(
                        comment: displayedComment,
                        isRunningLike: isRunningLike(displayedComment),
                        onReply: { onReply(displayedComment) },
                        onShowReplies: {},
                        onLike: { like(displayedComment, isPositive: true) },
                        onDislike: { like(displayedComment, isPositive: false) },
                        onReport: { reportTarget = displayedComment }
                    )

                    ForEach(replies.comments) { reply in
                        CommentRowView(
                            comment: reply,
                            isRunningLike: isRunningLike(reply),
                            onReply: { onReply(reply) },
                            onShowReplies: {},
                            onLike: { like(reply, isPositive: true) },
                            onDislike: { like(reply, isPositive: false) },
                            onReport: { reportTarget = reply }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await viewModel.loadReplies(for: displayedComment))
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }

    private func like(_ comment: CommentRow, isPositive: Bool) {
        Task { @MainActor in
            do {
                let updated = try await viewModel.likeAndReturn(comment: comment, isPositive: isPositive)
                if displayedComment.id == comment.id {
                    displayedComment = updated
                }
                if case .loaded(let snapshot) = state {
                    state = .loaded(snapshot.updatingComment(id: comment.id, with: updated))
                }
            } catch {
                viewModel.actionMessage = ErrorMessage.userFriendly(error)
            }
        }
    }

    private func isRunningLike(_ comment: CommentRow) -> Bool {
        viewModel.runningActionIDs.contains("like-\(comment.id)")
    }

    private var reportDialogBinding: Binding<Bool> {
        Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        )
    }
}

private enum RepliesState {
    case loading
    case loaded(CommentThreadScreenSnapshot)
    case failed(String)
}

private struct CommentTextSheet: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let submitTitle: LocalizedStringKey
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        CompatibleNavigationStack {
            VStack {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
                    .padding()
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle, action: onSubmit)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
            }
        }
    }
}

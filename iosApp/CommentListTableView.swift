import SwiftUI
import UIKit

struct CommentListTableModel {
    let state: CommentViewModel.State
    let sortMode: CommentViewModel.SortMode
    let runningActionIDs: Set<String>
    let comments: [CommentRow]
    let onChangeSortMode: (CommentViewModel.SortMode) -> Void
    let onRefresh: () -> Void
    let onRetry: () -> Void
    let onReply: (CommentRow) -> Void
    let onShowReplies: (CommentRow) -> Void
    let onLike: (CommentRow) -> Void
    let onDislike: (CommentRow) -> Void
    let onReport: (CommentRow) -> Void
}

final class CommentListTableController: NSObject, UITableViewDataSource, UITableViewDelegate {
    private enum StateSignature: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)

        init(_ state: CommentViewModel.State) {
            switch state {
            case .idle:
                self = .idle
            case .loading:
                self = .loading
            case .loaded:
                self = .loaded
            case .failed(let message):
                self = .failed(message)
            }
        }
    }

    private struct ModelSignature: Equatable {
        let state: StateSignature
        let sortMode: CommentViewModel.SortMode
        let comments: [CommentSignature]

        init(_ model: CommentListTableModel) {
            state = StateSignature(model.state)
            sortMode = model.sortMode
            comments = model.comments.map(CommentSignature.init)
        }
    }

    private struct CommentSignature: Equatable {
        let id: String
        let username: String
        let date: String
        let content: String
        let hasMoreReplies: Bool
        let replyCount: Int?

        init(_ comment: CommentRow) {
            id = comment.id
            username = comment.username
            date = comment.date
            content = comment.content
            hasMoreReplies = comment.hasMoreReplies
            replyCount = comment.replyCount
        }
    }

    private struct CommentActionSignature: Equatable {
        let id: String
        let thumbUp: Int?
        let likeCommentStatus: Bool
        let unlikeCommentStatus: Bool

        init(_ comment: CommentRow) {
            id = comment.id
            thumbUp = comment.thumbUp
            likeCommentStatus = comment.likeCommentStatus
            unlikeCommentStatus = comment.unlikeCommentStatus
        }
    }

    private enum Row {
        case controls
        case loading
        case failed(String)
        case empty
        case comment(CommentRow)
        case footer
    }

    private(set) weak var tableView: UITableView?
    private var rows: [Row] = []
    private var sortMode: CommentViewModel.SortMode = .mostLikes
    private var comments: [CommentRow] = []
    private var runningActionIDs: Set<String> = []
    private var onChangeSortMode: (CommentViewModel.SortMode) -> Void = { _ in }
    private var onRefresh: () -> Void = {}
    private var onRetry: () -> Void = {}
    private var onReply: (CommentRow) -> Void = { _ in }
    private var onShowReplies: (CommentRow) -> Void = { _ in }
    private var onLike: (CommentRow) -> Void = { _ in }
    private var onDislike: (CommentRow) -> Void = { _ in }
    private var onReport: (CommentRow) -> Void = { _ in }
    private var modelSignature: ModelSignature?
    private var commentActionSignatures: [CommentActionSignature] = []
    private var previousRunningActionIDs: Set<String> = []
    private var hasRenderedRows = false
    private var contentBottomPadding: CGFloat = 0
    weak var scrollDelegate: UIScrollViewDelegate?

    func attach(_ tableView: UITableView) {
        self.tableView = tableView
        configure(tableView)
        tableView.dataSource = self
        tableView.delegate = self
    }

    func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        attach(tableView)
        return tableView
    }

    func update(_ model: CommentListTableModel) {
        let nextSignature = ModelSignature(model)
        let shouldReload = modelSignature != nextSignature
        let nextCommentActionSignatures = model.comments.map(CommentActionSignature.init)
        let didChangeCommentActions = commentActionSignatures != nextCommentActionSignatures
        let didChangeRunningActions = previousRunningActionIDs != model.runningActionIDs
        modelSignature = nextSignature
        commentActionSignatures = nextCommentActionSignatures
        previousRunningActionIDs = model.runningActionIDs
        sortMode = model.sortMode
        comments = model.comments
        runningActionIDs = model.runningActionIDs
        onChangeSortMode = model.onChangeSortMode
        onRefresh = model.onRefresh
        onRetry = model.onRetry
        onReply = model.onReply
        onShowReplies = model.onShowReplies
        onLike = model.onLike
        onDislike = model.onDislike
        onReport = model.onReport
        let shouldReloadForActionChange = didChangeCommentActions
            && (model.sortMode == .mostLikes || model.sortMode == .mostDislikes)
        guard shouldReload else {
            if shouldReloadForActionChange {
                rows = rows(for: model)
                reloadTablePreservingOffset()
            } else if didChangeRunningActions || didChangeCommentActions {
                rows = rows(for: model)
                updateVisibleCommentRows()
            }
            return
        }
        rows = rows(for: model)
        reloadTablePreservingOffset()
    }

    func updateContentBottomPadding(_ bottomPadding: CGFloat) {
        let nextPadding = max(bottomPadding, 0)
        guard let tableView else {
            contentBottomPadding = nextPadding
            return
        }
        guard abs(contentBottomPadding - nextPadding) > 0.5
            || abs(tableView.contentInset.bottom - nextPadding) > 0.5
            || abs(tableView.verticalScrollIndicatorInsets.bottom - nextPadding) > 0.5 else {
            return
        }
        applyContentBottomPadding(nextPadding, in: tableView)
    }

    private func applyContentBottomPadding(_ nextPadding: CGFloat, in tableView: UITableView) {
        contentBottomPadding = nextPadding
        let bottomInset = max(nextPadding, 0)
        if abs(tableView.contentInset.bottom - bottomInset) > 0.5 {
            tableView.contentInset.bottom = bottomInset
        }
        if abs(tableView.verticalScrollIndicatorInsets.bottom - bottomInset) > 0.5 {
            tableView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .controls:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCommentTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? HostingCommentTableViewCell ?? HostingCommentTableViewCell(style: .default, reuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
            cell.configure {
                CommentListControlsRowView(
                    sortMode: sortMode,
                    onChangeSortMode: { [weak self] mode in self?.onChangeSortMode(mode) },
                    onRefresh: { [weak self] in self?.onRefresh() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)
            }
            return cell
        case .loading:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCommentTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? HostingCommentTableViewCell ?? HostingCommentTableViewCell(style: .default, reuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
            cell.configure {
                CommentListLoadingRowView()
            }
            return cell
        case .failed(let message):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCommentTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? HostingCommentTableViewCell ?? HostingCommentTableViewCell(style: .default, reuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
            cell.configure {
                CommentListFailedRowView(
                    message: message,
                    onRetry: { [weak self] in self?.onRetry() }
                )
            }
            return cell
        case .empty:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCommentTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? HostingCommentTableViewCell ?? HostingCommentTableViewCell(style: .default, reuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
            cell.configure {
                CommentListEmptyRowView()
            }
            return cell
        case .footer:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CommentListFooterCell.reuseIdentifier,
                for: indexPath
            ) as? CommentListFooterCell ?? CommentListFooterCell(style: .default, reuseIdentifier: CommentListFooterCell.reuseIdentifier)
            cell.configure()
            return cell
        case .comment(let comment):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCommentTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? HostingCommentTableViewCell ?? HostingCommentTableViewCell(style: .default, reuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
            cell.configure(
                comment: comment,
                isRunningLike: runningActionIDs.contains("like-\(comment.id)"),
                onReply: { [weak self] in self?.onReply(comment) },
                onShowReplies: { [weak self] in self?.onShowReplies(comment) },
                onLike: { [weak self] in self?.onLike(comment) },
                onDislike: { [weak self] in self?.onDislike(comment) },
                onReport: { [weak self] in self?.onReport(comment) }
            )
            return cell
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollDelegate?.scrollViewDidScroll?(scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        scrollDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollDelegate?.scrollViewDidEndDecelerating?(scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
    }

    private func configure(_ tableView: UITableView) {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.estimatedRowHeight = 118
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.register(HostingCommentTableViewCell.self, forCellReuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
        tableView.register(CommentListFooterCell.self, forCellReuseIdentifier: CommentListFooterCell.reuseIdentifier)
    }

    private func rows(for model: CommentListTableModel) -> [Row] {
        switch model.state {
        case .idle, .loading:
            return [.controls, .loading]
        case .failed(let message):
            return [.controls, .failed(message)]
        case .loaded:
            guard !model.comments.isEmpty else {
                return [.controls, .empty]
            }
            return [.controls] + model.comments.map { .comment($0) } + [.footer]
        }
    }

    private func updateVisibleCommentRows() {
        guard let tableView else { return }
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard indexPath.row < rows.count,
                  case .comment(let comment) = rows[indexPath.row],
                  let cell = tableView.cellForRow(at: indexPath) as? HostingCommentTableViewCell else {
                continue
            }
            cell.configure(
                comment: comment,
                isRunningLike: runningActionIDs.contains("like-\(comment.id)"),
                onReply: { [weak self] in self?.onReply(comment) },
                onShowReplies: { [weak self] in self?.onShowReplies(comment) },
                onLike: { [weak self] in self?.onLike(comment) },
                onDislike: { [weak self] in self?.onDislike(comment) },
                onReport: { [weak self] in self?.onReport(comment) }
            )
        }
    }

    private func reloadTablePreservingOffset() {
        guard let tableView else { return }
        guard hasRenderedRows else {
            tableView.reloadData()
            tableView.layoutIfNeeded()
            hasRenderedRows = true
            return
        }
        UIView.performWithoutAnimation {
            tableView.reloadData()
            if !tableView.isTracking, !tableView.isDragging, !tableView.isDecelerating {
                tableView.layoutIfNeeded()
            }
        }
    }

}

private final class HostingCommentTableViewCell: UITableViewCell {
    static let reuseIdentifier = "HostingCommentTableViewCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        preservesSuperviewLayoutMargins = false
        contentView.preservesSuperviewLayoutMargins = false
        layoutMargins = .zero
        contentView.layoutMargins = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentConfiguration = nil
    }

    func configure<Content: View>(@ViewBuilder content: () -> Content) {
        contentConfiguration = UIHostingConfiguration {
            content()
        }
        .margins(.all, 0)
    }

    func configure(
        comment: CommentRow,
        isRunningLike: Bool,
        onReply: @escaping () -> Void,
        onShowReplies: @escaping () -> Void,
        onLike: @escaping () -> Void,
        onDislike: @escaping () -> Void,
        onReport: @escaping () -> Void
    ) {
        let row = CommentRowView(
            comment: comment,
            isRunningLike: isRunningLike,
            onReply: onReply,
            onShowReplies: onShowReplies,
            onLike: onLike,
            onDislike: onDislike,
            onReport: onReport
        )
        .padding(.vertical, 6)
        .padding(.horizontal, 16)

        contentConfiguration = UIHostingConfiguration {
            row
        }
        .margins(.all, 0)
    }
}

private struct CommentListControlsRowView: View {
    let sortMode: CommentViewModel.SortMode
    let onChangeSortMode: (CommentViewModel.SortMode) -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(CommentViewModel.SortMode.allCases) { mode in
                    Button {
                        onChangeSortMode(mode)
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

            TapOnlyControl(action: onRefresh) {
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

private struct CommentListLoadingRowView: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 60)
    }
}

private struct CommentListFailedRowView: View {
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
            TapOnlyControl(action: onRetry) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 60)
    }
}

private struct CommentListEmptyRowView: View {
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
        .padding(.vertical, 60)
    }
}

private final class CommentListFooterCell: UITableViewCell {
    static let reuseIdentifier = "CommentListFooterCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        contentConfiguration = UIHostingConfiguration {
            Text("comment.no_more")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .margins(.all, 0)
    }
}

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

    private struct MeasuredCommentHeight {
        let signature: CommentSignature
        let height: CGFloat
    }

    private enum RowHeightEstimate {
        static let controls: CGFloat = 61
        static let loading: CGFloat = 120
        static let failed: CGFloat = 230
        static let empty: CGFloat = 180
        static let footer: CGFloat = 44
        static let commentMinimum: CGFloat = 118
        static let commentLineHeight: CGFloat = 22
        static let commentCharactersPerLine: CGFloat = 22

        static func comment(_ comment: CommentRow) -> CGFloat {
            let normalizedLength = max(comment.content.count, 1)
            let estimatedLines = ceil(CGFloat(normalizedLength) / commentCharactersPerLine)
            let replyHeight: CGFloat = comment.hasMoreReplies ? 18 : 0
            let childReduction: CGFloat = comment.isChildComment ? 8 : 0
            return max(commentMinimum - childReduction, 92 + estimatedLines * commentLineHeight + replyHeight)
        }
    }

    private enum Row {
        case controls
        case loading
        case failed(String)
        case empty
        case comment(CommentRow)
        case footer
        case bottomSpacer(CGFloat)
    }

    private(set) weak var tableView: UITableView?
    private var rows: [Row] = []
    private var sortMode: CommentViewModel.SortMode = .mostLikes
    private var comments: [CommentRow] = []
    private var bottomSpacerHeight: CGFloat = 0
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
    private var measuredCommentHeights: [String: MeasuredCommentHeight] = [:]
    private var isUpdatingMeasuredHeights = false
    private var isReloadingRows = false
    private var hasPendingMeasuredHeightLayoutUpdate = false
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

    func update(_ model: CommentListTableModel, bottomSpacerHeight: CGFloat = 0) {
        let nextSignature = ModelSignature(model)
        let shouldReload = modelSignature != nextSignature
        let nextCommentActionSignatures = model.comments.map(CommentActionSignature.init)
        let didChangeCommentActions = commentActionSignatures != nextCommentActionSignatures
        let didChangeRunningActions = previousRunningActionIDs != model.runningActionIDs
        let resolvedBottomSpacerHeight = max(bottomSpacerHeight, 0)
        let didChangeBottomSpacerHeight = abs(self.bottomSpacerHeight - resolvedBottomSpacerHeight) > 0.5
        pruneMeasuredCommentHeights(for: model)
        modelSignature = nextSignature
        commentActionSignatures = nextCommentActionSignatures
        previousRunningActionIDs = model.runningActionIDs
        sortMode = model.sortMode
        comments = model.comments
        self.bottomSpacerHeight = resolvedBottomSpacerHeight
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
            } else if didChangeBottomSpacerHeight {
                let previousRowCount = rows.count
                rows = rows(for: model)
                if rows.count != previousRowCount {
                    reloadTablePreservingOffset()
                } else {
                    updateTableLayoutPreservingOffset()
                }
            }
            return
        }
        rows = rows(for: model)
        reloadTablePreservingOffset()
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
        case .bottomSpacer(let height):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CommentListBottomSpacerCell.reuseIdentifier,
                for: indexPath
            ) as? CommentListBottomSpacerCell ?? CommentListBottomSpacerCell(style: .default, reuseIdentifier: CommentListBottomSpacerCell.reuseIdentifier)
            cell.configure(height: height)
            return cell
        case .comment(let comment):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCommentTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? HostingCommentTableViewCell ?? HostingCommentTableViewCell(style: .default, reuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
            cell.configure(
                comment: comment,
                isRunningLike: runningActionIDs.contains("like-\(comment.id)"),
                onMeasuredHeight: { [weak self, weak tableView] height in
                    self?.recordMeasuredCommentHeight(height, commentID: comment.id, tableView: tableView)
                },
                onReply: { [weak self] in self?.onReply(comment) },
                onShowReplies: { [weak self] in self?.onShowReplies(comment) },
                onLike: { [weak self] in self?.onLike(comment) },
                onDislike: { [weak self] in self?.onDislike(comment) },
                onReport: { [weak self] in self?.onReport(comment) }
            )
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < rows.count else { return UITableView.automaticDimension }
        if case .bottomSpacer(let height) = rows[indexPath.row] {
            return max(height, 0)
        }
        if case .footer = rows[indexPath.row] {
            return RowHeightEstimate.footer
        }
        if case .comment(let comment) = rows[indexPath.row],
           let measuredHeight = measuredCommentHeights[comment.id],
           measuredHeight.signature == CommentSignature(comment) {
            return measuredHeight.height
        }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < rows.count else { return UITableView.automaticDimension }
        switch rows[indexPath.row] {
        case .controls:
            return RowHeightEstimate.controls
        case .loading:
            return RowHeightEstimate.loading
        case .failed:
            return RowHeightEstimate.failed
        case .empty:
            return RowHeightEstimate.empty
        case .comment(let comment):
            return RowHeightEstimate.comment(comment)
        case .footer:
            return RowHeightEstimate.footer
        case .bottomSpacer(let height):
            return max(height, 0)
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
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.register(HostingCommentTableViewCell.self, forCellReuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
        tableView.register(CommentListFooterCell.self, forCellReuseIdentifier: CommentListFooterCell.reuseIdentifier)
        tableView.register(CommentListBottomSpacerCell.self, forCellReuseIdentifier: CommentListBottomSpacerCell.reuseIdentifier)
    }

    private func rows(for model: CommentListTableModel) -> [Row] {
        switch model.state {
        case .idle, .loading:
            return [.controls, .loading]
        case .failed(let message):
            return [.controls, .failed(message)]
        case .loaded:
            guard !model.comments.isEmpty else {
                return rowsWithBottomSpacer([.controls, .empty])
            }
            return rowsWithBottomSpacer([.controls] + model.comments.map { .comment($0) } + [.footer])
        }
    }

    private func rowsWithBottomSpacer(_ baseRows: [Row]) -> [Row] {
        guard bottomSpacerHeight > 0.5 else { return baseRows }
        return baseRows + [.bottomSpacer(bottomSpacerHeight)]
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
                onMeasuredHeight: { [weak self, weak tableView] height in
                    self?.recordMeasuredCommentHeight(height, commentID: comment.id, tableView: tableView)
                },
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
            isReloadingRows = true
            defer { isReloadingRows = false }
            tableView.reloadData()
            tableView.layoutIfNeeded()
            hasRenderedRows = true
            return
        }
        let previousOffset = tableView.contentOffset
        UIView.performWithoutAnimation {
            isReloadingRows = true
            defer { isReloadingRows = false }
            tableView.reloadData()
            if !tableView.isTracking, !tableView.isDragging, !tableView.isDecelerating {
                tableView.layoutIfNeeded()
            }
            tableView.setContentOffset(
                clampedContentOffset(previousOffset, in: tableView),
                animated: false
            )
        }
    }

    private func updateTableLayoutPreservingOffset() {
        guard let tableView else { return }
        let previousOffset = tableView.contentOffset
        isUpdatingMeasuredHeights = true
        defer { isUpdatingMeasuredHeights = false }
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.setContentOffset(
                clampedContentOffset(previousOffset, in: tableView),
                animated: false
            )
        }
    }

    private func clampedContentOffset(_ offset: CGPoint, in tableView: UITableView) -> CGPoint {
        let inset = tableView.adjustedContentInset
        let minOffsetY = -inset.top
        let maxOffsetY = max(minOffsetY, tableView.contentSize.height - tableView.bounds.height + inset.bottom)
        return CGPoint(
            x: offset.x,
            y: min(max(offset.y, minOffsetY), maxOffsetY)
        )
    }

    private func pruneMeasuredCommentHeights(for model: CommentListTableModel) {
        let validSignatures = Dictionary(uniqueKeysWithValues: model.comments.map { ($0.id, CommentSignature($0)) })
        measuredCommentHeights = measuredCommentHeights.filter { id, measured in
            validSignatures[id] == measured.signature
        }
    }

    private func recordMeasuredCommentHeight(
        _ height: CGFloat,
        commentID: String,
        tableView: UITableView?
    ) {
        guard height > 1 else { return }
        let roundedHeight = ceil(height)
        guard let comment = comments.first(where: { $0.id == commentID }) else { return }
        let signature = CommentSignature(comment)
        guard measuredCommentHeights[commentID].map({
            $0.signature != signature || abs($0.height - roundedHeight) > 0.5
        }) ?? true else { return }
        measuredCommentHeights[commentID] = MeasuredCommentHeight(
            signature: signature,
            height: roundedHeight
        )
        guard let tableView,
              !isUpdatingMeasuredHeights,
              !isReloadingRows,
              !tableView.isTracking,
              !tableView.isDragging,
              !tableView.isDecelerating else { return }
        scheduleMeasuredHeightLayoutUpdate(tableView: tableView)
    }

    private func scheduleMeasuredHeightLayoutUpdate(tableView: UITableView) {
        guard !hasPendingMeasuredHeightLayoutUpdate else { return }
        hasPendingMeasuredHeightLayoutUpdate = true
        DispatchQueue.main.async { [weak self, weak tableView] in
            guard let self else { return }
            self.hasPendingMeasuredHeightLayoutUpdate = false
            guard let tableView,
                  !self.isUpdatingMeasuredHeights,
                  !self.isReloadingRows,
                  !tableView.isTracking,
                  !tableView.isDragging,
                  !tableView.isDecelerating else { return }
            self.updateTableLayoutPreservingOffset()
        }
    }
}

private final class HostingCommentTableViewCell: UITableViewCell {
    static let reuseIdentifier = "HostingCommentTableViewCell"
    private var onMeasuredHeight: ((CGFloat) -> Void)?

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
        onMeasuredHeight = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onMeasuredHeight?(bounds.height)
    }

    func configure<Content: View>(@ViewBuilder content: () -> Content) {
        onMeasuredHeight = nil
        contentConfiguration = UIHostingConfiguration {
            content()
        }
        .margins(.all, 0)
    }

    func configure(
        comment: CommentRow,
        isRunningLike: Bool,
        onMeasuredHeight: @escaping (CGFloat) -> Void,
        onReply: @escaping () -> Void,
        onShowReplies: @escaping () -> Void,
        onLike: @escaping () -> Void,
        onDislike: @escaping () -> Void,
        onReport: @escaping () -> Void
    ) {
        self.onMeasuredHeight = onMeasuredHeight
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

private final class CommentListBottomSpacerCell: UITableViewCell {
    static let reuseIdentifier = "CommentListBottomSpacerCell"

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

    func configure(height _: CGFloat) {
        contentConfiguration = nil
    }
}

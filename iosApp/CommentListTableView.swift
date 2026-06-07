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

struct CommentListTableView: UIViewRepresentable {
    private let mode: Mode

    private enum Mode {
        case full(CommentListTableModel)
        case rows(
            comments: [CommentRow],
            runningActionIDs: Set<String>,
            onReply: (CommentRow) -> Void,
            onShowReplies: (CommentRow) -> Void,
            onLike: (CommentRow) -> Void,
            onDislike: (CommentRow) -> Void,
            onReport: (CommentRow) -> Void
        )
    }

    init(model: CommentListTableModel) {
        mode = .full(model)
    }

    init(
        comments: [CommentRow],
        runningActionIDs: Set<String>,
        onReply: @escaping (CommentRow) -> Void,
        onShowReplies: @escaping (CommentRow) -> Void,
        onLike: @escaping (CommentRow) -> Void,
        onDislike: @escaping (CommentRow) -> Void,
        onReport: @escaping (CommentRow) -> Void
    ) {
        mode = .rows(
            comments: comments,
            runningActionIDs: runningActionIDs,
            onReply: onReply,
            onShowReplies: onShowReplies,
            onLike: onLike,
            onDislike: onDislike,
            onReport: onReport
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> IntrinsicCommentTableView {
        let tableView = IntrinsicCommentTableView(frame: .zero, style: .plain)
        tableView.isScrollEnabled = false
        tableView.alwaysBounceVertical = false
        context.coordinator.controller.attach(tableView)
        return tableView
    }

    func updateUIView(_ tableView: IntrinsicCommentTableView, context: Context) {
        switch mode {
        case .full(let model):
            context.coordinator.controller.update(model)
        case .rows(
            let comments,
            let runningActionIDs,
            let onReply,
            let onShowReplies,
            let onLike,
            let onDislike,
            let onReport
        ):
            context.coordinator.controller.updateRows(
                comments: comments,
                runningActionIDs: runningActionIDs,
                onReply: onReply,
                onShowReplies: onShowReplies,
                onLike: onLike,
                onDislike: onDislike,
                onReport: onReport
            )
        }
        tableView.invalidateIntrinsicContentSize()
    }

    final class Coordinator {
        let controller = CommentListTableController()
    }
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
        let runningActionIDs: Set<String>
        let comments: [CommentSignature]

        init(_ model: CommentListTableModel) {
            state = StateSignature(model.state)
            sortMode = model.sortMode
            runningActionIDs = model.runningActionIDs
            comments = model.comments.map(CommentSignature.init)
        }
    }

    private struct CommentSignature: Equatable {
        let id: String
        let username: String
        let date: String
        let content: String
        let thumbUp: Int?
        let hasMoreReplies: Bool
        let replyCount: Int?
        let likeCommentStatus: Bool
        let unlikeCommentStatus: Bool

        init(_ comment: CommentRow) {
            id = comment.id
            username = comment.username
            date = comment.date
            content = comment.content
            thumbUp = comment.thumbUp
            hasMoreReplies = comment.hasMoreReplies
            replyCount = comment.replyCount
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
        modelSignature = nextSignature
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
        guard shouldReload else { return }
        rows = rows(for: model)
        tableView?.reloadData()
    }

    func updateRows(
        comments: [CommentRow],
        runningActionIDs: Set<String>,
        onReply: @escaping (CommentRow) -> Void,
        onShowReplies: @escaping (CommentRow) -> Void,
        onLike: @escaping (CommentRow) -> Void,
        onDislike: @escaping (CommentRow) -> Void,
        onReport: @escaping (CommentRow) -> Void
    ) {
        self.comments = comments
        self.runningActionIDs = runningActionIDs
        self.onReply = onReply
        self.onShowReplies = onShowReplies
        self.onLike = onLike
        self.onDislike = onDislike
        self.onReport = onReport
        rows = comments.map { .comment($0) } + [.footer]
        tableView?.reloadData()
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
}

final class IntrinsicCommentTableView: UITableView {
    override var contentSize: CGSize {
        didSet {
            guard abs(contentSize.height - oldValue.height) > 0.5 else { return }
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
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

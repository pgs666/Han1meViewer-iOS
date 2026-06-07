import SwiftUI
import UIKit

struct CommentListTableView: UIViewRepresentable {
    let comments: [CommentRow]
    let runningActionIDs: Set<String>
    let onReply: (CommentRow) -> Void
    let onShowReplies: (CommentRow) -> Void
    let onLike: (CommentRow) -> Void
    let onDislike: (CommentRow) -> Void
    let onReport: (CommentRow) -> Void

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
        context.coordinator.controller.update(
            comments: comments,
            runningActionIDs: runningActionIDs,
            onReply: onReply,
            onShowReplies: onShowReplies,
            onLike: onLike,
            onDislike: onDislike,
            onReport: onReport
        )
        tableView.invalidateIntrinsicContentSize()
    }

    final class Coordinator {
        let controller = CommentListTableController()
    }
}

final class CommentListTableController: NSObject, UITableViewDataSource, UITableViewDelegate {
    private(set) weak var tableView: UITableView?
    private var comments: [CommentRow] = []
    private var runningActionIDs: Set<String> = []
    private var onReply: (CommentRow) -> Void = { _ in }
    private var onShowReplies: (CommentRow) -> Void = { _ in }
    private var onLike: (CommentRow) -> Void = { _ in }
    private var onDislike: (CommentRow) -> Void = { _ in }
    private var onReport: (CommentRow) -> Void = { _ in }

    func attach(_ tableView: UITableView) {
        self.tableView = tableView
        configure(tableView)
        tableView.dataSource = self
        tableView.delegate = self
    }

    func update(
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
        tableView?.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        comments.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == comments.count {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CommentListFooterCell.reuseIdentifier,
                for: indexPath
            ) as? CommentListFooterCell ?? CommentListFooterCell(style: .default, reuseIdentifier: CommentListFooterCell.reuseIdentifier)
            cell.configure()
            return cell
        }

        let comment = comments[indexPath.row]
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

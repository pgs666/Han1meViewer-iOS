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
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> IntrinsicCommentTableView {
        let tableView = IntrinsicCommentTableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.isScrollEnabled = false
        tableView.alwaysBounceVertical = false
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.register(HostingCommentTableViewCell.self, forCellReuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
        tableView.register(CommentListFooterCell.self, forCellReuseIdentifier: CommentListFooterCell.reuseIdentifier)
        return tableView
    }

    func updateUIView(_ tableView: IntrinsicCommentTableView, context: Context) {
        context.coordinator.parent = self
        tableView.reloadData()
        tableView.invalidateIntrinsicContentSize()
    }

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: CommentListTableView

        init(parent: CommentListTableView) {
            self.parent = parent
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            parent.comments.count + 1
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            if indexPath.row == parent.comments.count {
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: CommentListFooterCell.reuseIdentifier,
                    for: indexPath
                ) as? CommentListFooterCell ?? CommentListFooterCell(style: .default, reuseIdentifier: CommentListFooterCell.reuseIdentifier)
                cell.configure()
                return cell
            }

            let comment = parent.comments[indexPath.row]
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCommentTableViewCell.reuseIdentifier,
                for: indexPath
            ) as? HostingCommentTableViewCell ?? HostingCommentTableViewCell(style: .default, reuseIdentifier: HostingCommentTableViewCell.reuseIdentifier)
            cell.configure(
                comment: comment,
                isRunningLike: parent.runningActionIDs.contains("like-\(comment.id)"),
                onReply: { [weak self] in self?.parent.onReply(comment) },
                onShowReplies: { [weak self] in self?.parent.onShowReplies(comment) },
                onLike: { [weak self] in self?.parent.onLike(comment) },
                onDislike: { [weak self] in self?.parent.onDislike(comment) },
                onReport: { [weak self] in self?.parent.onReport(comment) }
            )
            return cell
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

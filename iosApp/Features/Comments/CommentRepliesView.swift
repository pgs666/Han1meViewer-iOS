import SwiftUI

struct CommentRepliesView: View {
    @StateObject private var viewModel: CommentRepliesViewModel
    @State private var reportTarget: CommentRow?
    @State private var replyTarget: CommentRow?
    @State private var replyText = ""

    init(comment: CommentRow, commentViewModel: CommentViewModel) {
        _viewModel = StateObject(
            wrappedValue: CommentRepliesViewModel(
                comment: comment,
                commentViewModel: commentViewModel
            )
        )
    }

    var body: some View {
        CompatibleNavigationStack {
            content
                .navigationTitle("回复")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load() }
        .sheet(item: $replyTarget) { comment in
            CommentComposerView(
                title: "回复 \(comment.username)",
                text: $replyText,
                placeholder: "输入回复",
                submitTitle: "回复",
                onCancel: clearReply,
                onSubmit: { submitReply(to: comment) }
            )
            .presentationDragIndicator(.visible)
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
            Button("取消", role: .cancel) { reportTarget = nil }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Text("回复加载失败").font(.headline)
                Text(message).foregroundStyle(.secondary)
                Button("重试") { Task { await viewModel.load() } }
                CloudflareVerifyButton(errorMessage: message)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let replies):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    commentRow(viewModel.displayedComment)
                    ForEach(replies.comments) { reply in
                        commentRow(reply)
                    }
                }
                .padding()
            }
        }
    }

    private func commentRow(_ comment: CommentRow) -> some View {
        CommentRowView(
            comment: comment,
            isRunningLike: viewModel.isRunningLike(comment),
            onReply: { presentReply(to: comment) },
            onShowReplies: {},
            onLike: { Task { await viewModel.like(comment, isPositive: true) } },
            onDislike: { Task { await viewModel.like(comment, isPositive: false) } },
            onReport: { reportTarget = comment }
        )
    }

    private func presentReply(to comment: CommentRow) {
        replyText = "@\(comment.username) "
        replyTarget = comment
    }

    private func submitReply(to comment: CommentRow) {
        let text = replyText
        Task {
            guard await viewModel.submitReply(to: comment, text: text) else { return }
            clearReply()
        }
    }

    private func clearReply() {
        replyTarget = nil
        replyText = ""
    }

    private var reportDialogBinding: Binding<Bool> {
        Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        )
    }
}

import SwiftUI

struct CommentView: View {
    @ObservedObject var viewModel: CommentViewModel

    @State private var composeText = ""
    @State private var isShowingComposer = false
    @State private var replyTarget: CommentRow?
    @State private var replyText = ""
    @State private var reportTarget: CommentRow?
    @State private var repliesTarget: CommentRow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .task { viewModel.loadIfNeeded() }
        .alert("提示", isPresented: actionMessageBinding) {
            Button("好", role: .cancel) { viewModel.actionMessage = nil }
        } message: {
            Text(viewModel.actionMessage ?? "")
        }
        .sheet(isPresented: $isShowingComposer) {
            CommentComposerView(
                title: "发表评论",
                text: $composeText,
                placeholder: "输入评论",
                submitTitle: "发送",
                onCancel: clearComposer,
                onSubmit: submitComment
            )
            .presentationDragIndicator(.visible)
        }
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
        .sheet(item: $repliesTarget) { comment in
            CommentRepliesView(comment: comment, commentViewModel: viewModel)
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

    private var header: some View {
        HStack(spacing: 12) {
            Picker("排序", selection: $viewModel.sortMode) {
                ForEach(CommentViewModel.SortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            Spacer()
            Button { isShowingComposer = true } label: {
                Label("评论", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "text.bubble")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("评论加载失败").font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("重试") { viewModel.load() }
                    .buttonStyle(.borderedProminent)
                CloudflareVerifyButton(errorMessage: message)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        case .loaded:
            if viewModel.sortedComments.isEmpty {
                emptyState
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.sortedComments) { comment in
                        commentRow(comment)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无评论").font(.headline)
            Text("成为第一个评论的人。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func commentRow(_ comment: CommentRow) -> some View {
        CommentRowView(
            comment: comment,
            isRunningLike: viewModel.runningActionIDs.contains("like-\(comment.id)"),
            onReply: {
                replyText = "@\(comment.username) "
                replyTarget = comment
            },
            onShowReplies: { repliesTarget = comment },
            onLike: { viewModel.like(comment: comment, isPositive: true) },
            onDislike: { viewModel.like(comment: comment, isPositive: false) },
            onReport: { reportTarget = comment }
        )
    }

    private func submitComment() {
        let text = composeText
        Task {
            guard await viewModel.postComment(text: text) else { return }
            clearComposer()
        }
    }

    private func submitReply(to comment: CommentRow) {
        let text = replyText
        Task {
            guard await viewModel.postReply(to: comment, text: text) else { return }
            clearReply()
        }
    }

    private func clearComposer() {
        isShowingComposer = false
        composeText = ""
    }

    private func clearReply() {
        replyTarget = nil
        replyText = ""
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
}

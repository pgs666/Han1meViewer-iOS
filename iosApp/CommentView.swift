import SwiftUI
import Han1meShared

struct CommentView: View {
    @ObservedObject private var viewModel: CommentViewModel
    private let onOverlayActivityChanged: (Bool) -> Void
    @State private var replyTarget: CommentRow?
    @State private var replyText = ""
    @State private var reportTarget: CommentRow?
    @State private var repliesTarget: CommentRow?

    init(
        viewModel: CommentViewModel,
        onOverlayActivityChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onOverlayActivityChanged = onOverlayActivityChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(.horizontal, 16)
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

    private var header: some View {
        HStack(spacing: 12) {
            Picker("排序", selection: $viewModel.sortMode) {
                ForEach(CommentViewModel.SortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .horizontalPagerExclusionArea()

            Spacer()

            TapOnlyControl {
                viewModel.load()
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

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 60)
        case .failed(let message):
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
                    viewModel.load()
                } label: {
                    Text("重试")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                CloudflareVerifyButton(errorMessage: message)
                    .horizontalPagerExclusionArea()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        case .loaded:
            let comments = viewModel.sortedComments
            if comments.isEmpty {
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
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(comments) { comment in
                        CommentRowView(
                            comment: comment,
                            isRunningLike: viewModel.runningActionIDs.contains("like-\(comment.id)"),
                            onReply: {
                                replyText = "@\(comment.username) "
                                replyTarget = comment
                            },
                            onShowReplies: {
                                repliesTarget = comment
                            },
                            onLike: {
                                viewModel.like(comment: comment, isPositive: true)
                            },
                            onDislike: {
                                viewModel.like(comment: comment, isPositive: false)
                            },
                            onReport: {
                                reportTarget = comment
                            }
                        )
                    }

                    Text("comment.no_more")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
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

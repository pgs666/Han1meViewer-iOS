import SwiftUI
import Han1meShared
import UIKit

struct CommentView: View {
    @ObservedObject var viewModel: CommentViewModel
    let isActive: Bool
    let onPresentAction: () -> Void
    let onScrollDirectionChange: (Bool) -> Void

    @State private var replyTarget: CommentRow?
    @State private var replyText = ""
    @State private var reportTarget: CommentRow?
    @State private var repliesTarget: CommentRow?
    @State private var accumulatedScrollDelta: CGFloat = 0
    @State private var isComposerShownForScroll = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background {
                CommentScrollDirectionObserver { delta in
                    guard isActive else { return }
                    updateScrollDirection(delta: delta)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            viewModel.loadIfNeeded()
        }
        .onValueChange(of: isActive) { isActive in
            accumulatedScrollDelta = 0
            if isActive {
                setComposerShownForScroll(true)
            }
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
                    submitReply(to: comment)
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $repliesTarget) { comment in
            CommentRepliesSheet(
                comment: comment,
                viewModel: viewModel
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

            Spacer()
        }
    }

    private func submitReply(to comment: CommentRow) {
        let text = replyText
        Task { @MainActor in
            guard await viewModel.postReply(to: comment, text: text) else { return }
            replyTarget = nil
            replyText = ""
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
                Button("重试") {
                    viewModel.load()
                }
                .buttonStyle(.borderedProminent)
                CloudflareVerifyButton(errorMessage: message)
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
                                onPresentAction()
                                replyText = "@\(comment.username) "
                                replyTarget = comment
                            },
                            onShowReplies: {
                                onPresentAction()
                                repliesTarget = comment
                            },
                            onLike: {
                                viewModel.like(comment: comment, isPositive: true)
                            },
                            onDislike: {
                                viewModel.like(comment: comment, isPositive: false)
                            },
                            onReport: {
                                onPresentAction()
                                reportTarget = comment
                            }
                        )
                    }
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

    private func updateScrollDirection(delta: CGFloat) {
        guard delta != 0 else { return }
        guard case .loaded = viewModel.state, !viewModel.sortedComments.isEmpty else {
            accumulatedScrollDelta = 0
            setComposerShownForScroll(true)
            return
        }

        if (accumulatedScrollDelta > 0 && delta < 0)
            || (accumulatedScrollDelta < 0 && delta > 0) {
            accumulatedScrollDelta = delta
        } else {
            accumulatedScrollDelta += delta
        }

        if accumulatedScrollDelta <= -14 {
            accumulatedScrollDelta = 0
            setComposerShownForScroll(false)
        } else if accumulatedScrollDelta >= 10 {
            accumulatedScrollDelta = 0
            setComposerShownForScroll(true)
        }
    }

    private func setComposerShownForScroll(_ isShown: Bool) {
        guard isComposerShownForScroll != isShown else { return }
        isComposerShownForScroll = isShown
        onScrollDirectionChange(isShown)
    }
}

private struct CommentScrollDirectionObserver: UIViewRepresentable {
    let onScrollDelta: (CGFloat) -> Void

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.isUserInteractionEnabled = false
        view.onScrollDelta = onScrollDelta
        return view
    }

    func updateUIView(_ uiView: ObserverView, context: Context) {
        uiView.onScrollDelta = onScrollDelta
        uiView.scheduleAttachment()
    }

    static func dismantleUIView(_ uiView: ObserverView, coordinator: ()) {
        uiView.detach()
    }

    final class ObserverView: UIView {
        var onScrollDelta: (CGFloat) -> Void = { _ in }

        private weak var observedScrollView: UIScrollView?
        private weak var observedPanGesture: UIPanGestureRecognizer?
        private var previousContentOffsetY: CGFloat?
        private var isAttachmentScheduled = false

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            scheduleAttachment()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                detach()
            } else {
                scheduleAttachment()
            }
        }

        func scheduleAttachment() {
            guard !isAttachmentScheduled else { return }
            isAttachmentScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isAttachmentScheduled = false
                self.attachToEnclosingScrollView()
            }
        }

        func detach() {
            observedPanGesture?.removeTarget(self, action: #selector(handlePan(_:)))
            observedPanGesture = nil
            observedScrollView = nil
            previousContentOffsetY = nil
        }

        private func attachToEnclosingScrollView() {
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    guard observedScrollView !== scrollView else { return }
                    detach()
                    observedScrollView = scrollView
                    observedPanGesture = scrollView.panGestureRecognizer
                    scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))
                    return
                }
                ancestor = view.superview
            }
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView = observedScrollView else { return }

            switch recognizer.state {
            case .began:
                previousContentOffsetY = scrollView.contentOffset.y
            case .changed:
                let contentOffsetY = scrollView.contentOffset.y
                guard let previousContentOffsetY else {
                    self.previousContentOffsetY = contentOffsetY
                    return
                }
                self.previousContentOffsetY = contentOffsetY

                let delta = previousContentOffsetY - contentOffsetY
                guard delta != 0, abs(delta) < 80 else { return }
                onScrollDelta(delta)
            case .ended, .cancelled, .failed:
                previousContentOffsetY = nil
            default:
                break
            }
        }
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
                    Menu {
                        Button("举报", role: .destructive, action: onReport)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(comment.content)
                    .font(.body)
                    .textSelection(.enabled)

                HStack(spacing: 14) {
                    Button(action: onLike) {
                        Label("\(comment.thumbUp ?? 0)", systemImage: comment.likeCommentStatus ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }
                    .disabled(isRunningLike)

                    Button(action: onDislike) {
                        Image(systemName: comment.unlikeCommentStatus ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    }
                    .disabled(isRunningLike)

                    Button("回复", action: onReply)

                    if comment.hasMoreReplies {
                        Button("查看 \(comment.replyCount ?? 0) 条回复", action: onShowReplies)
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
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

    @State private var state: RepliesState = .loading
    @State private var displayedComment: CommentRow
    @State private var reportTarget: CommentRow?
    @State private var replyTarget: CommentRow?
    @State private var replyText = ""

    init(
        comment: CommentRow,
        viewModel: CommentViewModel
    ) {
        self.viewModel = viewModel
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
                    submitReply(to: comment)
                }
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
                        onReply: { presentReply(to: displayedComment) },
                        onShowReplies: {},
                        onLike: { like(displayedComment, isPositive: true) },
                        onDislike: { like(displayedComment, isPositive: false) },
                        onReport: { reportTarget = displayedComment }
                    )

                    ForEach(replies.comments) { reply in
                        CommentRowView(
                            comment: reply,
                            isRunningLike: isRunningLike(reply),
                            onReply: { presentReply(to: reply) },
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
        await load(showsLoadingState: true)
    }

    private func load(showsLoadingState: Bool) async {
        if showsLoadingState {
            state = .loading
        }
        do {
            state = .loaded(try await viewModel.loadReplies(for: displayedComment))
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }

    private func presentReply(to comment: CommentRow) {
        replyText = "@\(comment.username) "
        replyTarget = comment
    }

    private func submitReply(to comment: CommentRow) {
        let text = replyText
        Task { @MainActor in
            guard await viewModel.postReply(to: comment, text: text) else { return }
            replyTarget = nil
            replyText = ""
            await load(showsLoadingState: false)
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

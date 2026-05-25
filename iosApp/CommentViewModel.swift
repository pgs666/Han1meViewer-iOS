import Foundation
import Han1meShared

@MainActor
final class CommentViewModel: ObservableObject {
    enum SortMode: String, CaseIterable, Identifiable {
        case latest
        case earliest
        case mostReplies
        case mostLikes
        case mostDislikes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .latest:
                return "最新"
            case .earliest:
                return "最早"
            case .mostReplies:
                return "最多回复"
            case .mostLikes:
                return "最多赞"
            case .mostDislikes:
                return "最少赞"
            }
        }
    }

    enum State {
        case idle
        case loading
        case loaded(CommentThreadScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var sortMode: SortMode = .latest
    @Published var actionMessage: String?
    @Published private(set) var runningActionIDs: Set<String> = []

    private let feature: CommentFeature
    private let videoCode: String
    private var loadTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(feature: CommentFeature, videoCode: String) {
        self.feature = feature
        self.videoCode = videoCode
    }

    deinit {
        loadTask?.cancel()
    }

    func loadIfNeeded() {
        if case .idle = state {
            load()
        }
    }

    func load() {
        loadTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        state = .loading
        loadTask = Task { [weak self] in
            await self?.loadComments(generation: generation)
        }
    }

    func postComment(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            actionMessage = "评论太短"
            return
        }
        guard let snapshot = currentSnapshot, let userId = snapshot.currentUserId else {
            actionMessage = "请先登录"
            return
        }

        runAction(id: "post-comment") {
            try await self.feature.postVideoComment(
                videoCode: self.videoCode,
                currentUserId: userId,
                csrfToken: snapshot.csrfToken,
                text: trimmed
            )
            self.actionMessage = "评论已发送"
            self.load()
        }
    }

    func postReply(to comment: CommentRow, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            actionMessage = "回复太短"
            return
        }
        guard currentSnapshot?.currentUserId != nil else {
            actionMessage = "请先登录"
            return
        }
        guard let replyTargetId = comment.replyTargetId else {
            actionMessage = "无法回复这条评论"
            return
        }

        runAction(id: "reply-\(comment.id)") {
            try await self.feature.postReply(
                replyCommentId: replyTargetId,
                csrfToken: self.currentSnapshot?.csrfToken,
                text: trimmed
            )
            self.actionMessage = "回复已发送"
            self.load()
        }
    }

    func like(comment: CommentRow, isPositive: Bool) {
        Task { [weak self] in
            do {
                _ = try await self?.likeAndReturn(comment: comment, isPositive: isPositive)
            } catch is CancellationError {
                return
            } catch {
                self?.actionMessage = ErrorMessage.userFriendly(error)
            }
        }
    }

    func likeAndReturn(comment: CommentRow, isPositive: Bool) async throws -> CommentRow {
        guard currentSnapshot?.currentUserId != nil else {
            actionMessage = "请先登录"
            throw CommentViewModelError.loginRequired
        }
        let actionID = "like-\(comment.id)-\(isPositive)"
        guard !runningActionIDs.contains(actionID) else {
            return comment
        }
        runningActionIDs.insert(actionID)
        defer {
            runningActionIDs.remove(actionID)
        }

        let updated = try await feature.likeComment(
            csrfToken: currentSnapshot?.csrfToken,
            comment: comment.snapshot,
            isPositive: isPositive
        )
        let row = CommentRow(updated)
        updateComment(comment.id, with: row)
        return row
    }

    func report(comment: CommentRow, reason: ReportReasonRow) {
        guard let snapshot = currentSnapshot, snapshot.currentUserId != nil else {
            actionMessage = "请先登录"
            return
        }

        runAction(id: "report-\(comment.id)") {
            try await self.feature.reportComment(
                currentUserId: snapshot.currentUserId,
                csrfToken: snapshot.csrfToken,
                redirectUrl: "https://hanime1.me/watch?v=\(self.videoCode)",
                comment: comment.snapshot,
                reason: reason.value
            )
            self.actionMessage = "举报已提交"
        }
    }

    func loadReplies(for comment: CommentRow) async throws -> CommentThreadScreenSnapshot {
        guard let replyTargetId = comment.replyTargetId else {
            throw CommentViewModelError.missingReplyTarget
        }
        let snapshot = try await feature.loadReplies(commentId: replyTargetId)
        return CommentThreadScreenSnapshot(snapshot)
    }

    var sortedComments: [CommentRow] {
        guard let snapshot = currentSnapshot else {
            return []
        }
        switch sortMode {
        case .latest:
            return snapshot.comments
        case .earliest:
            return Array(snapshot.comments.reversed())
        case .mostReplies:
            return snapshot.comments.sorted { ($0.replyCount ?? 0) > ($1.replyCount ?? 0) }
        case .mostLikes:
            return snapshot.comments.sorted { ($0.thumbUp ?? 0) > ($1.thumbUp ?? 0) }
        case .mostDislikes:
            return snapshot.comments.sorted { ($0.thumbUp ?? 0) < ($1.thumbUp ?? 0) }
        }
    }

    var reportReasons: [ReportReasonRow] {
        let count = Int(feature.reportReasonCount())
        return (0..<count).compactMap { index in
            guard let reason = feature.reportReasonAt(index: Int32(index)) else {
                return nil
            }
            return ReportReasonRow(reason)
        }
    }

    private var currentSnapshot: CommentThreadScreenSnapshot? {
        if case .loaded(let snapshot) = state {
            return snapshot
        }
        return nil
    }

    private func loadComments(generation: Int) async {
        do {
            let snapshot = try await feature.loadVideoComments(videoCode: videoCode)
            guard !Task.isCancelled, generation == requestGeneration else { return }
            state = .loaded(CommentThreadScreenSnapshot(snapshot))
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == requestGeneration else { return }
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }

    private func runAction(id: String, action: @escaping () async throws -> Void) {
        guard !runningActionIDs.contains(id) else {
            return
        }
        runningActionIDs.insert(id)
        Task { [weak self] in
            guard let self else { return }
            defer {
                runningActionIDs.remove(id)
            }
            do {
                try await action()
            } catch is CancellationError {
                return
            } catch {
                CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
                actionMessage = ErrorMessage.userFriendly(error)
            }
        }
    }

    private func updateComment(_ id: String, with updated: CommentRow) {
        guard let snapshot = currentSnapshot else {
            return
        }
        state = .loaded(snapshot.updatingComment(id: id, with: updated))
    }
}

struct CommentThreadScreenSnapshot {
    let currentUserId: String?
    let csrfToken: String?
    let comments: [CommentRow]

    init(_ snapshot: CommentThreadSnapshot) {
        currentUserId = snapshot.currentUserId
        csrfToken = snapshot.csrfToken
        let count = Int(snapshot.commentCount())
        comments = (0..<count).compactMap { index in
            guard let comment = snapshot.commentAt(index: Int32(index)) else {
                return nil
            }
            return CommentRow(comment)
        }
    }

    private init(currentUserId: String?, csrfToken: String?, comments: [CommentRow]) {
        self.currentUserId = currentUserId
        self.csrfToken = csrfToken
        self.comments = comments
    }

    func updatingComment(id: String, with updated: CommentRow) -> CommentThreadScreenSnapshot {
        CommentThreadScreenSnapshot(
            currentUserId: currentUserId,
            csrfToken: csrfToken,
            comments: comments.map { $0.id == id ? updated : $0 }
        )
    }
}

struct CommentRow: Identifiable {
    let snapshot: CommentSnapshot
    let stableKey: String
    let avatarUrl: String
    let username: String
    let date: String
    let content: String
    let thumbUp: Int?
    let isChildComment: Bool
    let hasMoreReplies: Bool
    let replyCount: Int?
    let replyTargetId: String?
    let likeCommentStatus: Bool
    let unlikeCommentStatus: Bool
    let reportableId: String?
    let reportableType: String?

    init(_ snapshot: CommentSnapshot) {
        self.snapshot = snapshot
        stableKey = snapshot.stableKey
        avatarUrl = snapshot.avatarUrl
        username = snapshot.username
        date = snapshot.date
        content = snapshot.content
        thumbUp = snapshot.thumbUp?.intValue
        isChildComment = snapshot.isChildComment
        hasMoreReplies = snapshot.hasMoreReplies
        replyCount = snapshot.replyCount?.intValue
        replyTargetId = snapshot.replyTargetId
        likeCommentStatus = snapshot.likeCommentStatus
        unlikeCommentStatus = snapshot.unlikeCommentStatus
        reportableId = snapshot.reportableId
        reportableType = snapshot.reportableType
    }

    var id: String { stableKey }
}

struct ReportReasonRow: Identifiable {
    let title: String
    let value: String

    init(_ snapshot: ReportReasonSnapshot) {
        title = snapshot.title
        value = snapshot.value
    }

    var id: String { value }
}

enum CommentViewModelError: LocalizedError {
    case missingReplyTarget
    case loginRequired

    var errorDescription: String? {
        switch self {
        case .missingReplyTarget:
            return "无法加载回复"
        case .loginRequired:
            return "请先登录"
        }
    }
}

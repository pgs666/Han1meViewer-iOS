import Foundation

@MainActor
final class CommentRepliesViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(CommentThreadScreenSnapshot)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var displayedComment: CommentRow

    private let commentViewModel: CommentViewModel

    init(comment: CommentRow, commentViewModel: CommentViewModel) {
        displayedComment = comment
        self.commentViewModel = commentViewModel
    }

    var reportReasons: [ReportReasonRow] { commentViewModel.reportReasons }

    func isRunningLike(_ comment: CommentRow) -> Bool {
        commentViewModel.runningActionIDs.contains("like-\(comment.id)")
    }

    func load(showsLoadingState: Bool = true) async {
        if showsLoadingState { state = .loading }
        do {
            state = .loaded(try await commentViewModel.loadReplies(for: displayedComment))
        } catch {
            state = .failed(ErrorMessage.userFriendly(error))
        }
    }

    func submitReply(to comment: CommentRow, text: String) async -> Bool {
        guard await commentViewModel.postReply(to: comment, text: text) else { return false }
        await load(showsLoadingState: false)
        return true
    }

    func like(_ comment: CommentRow, isPositive: Bool) async {
        do {
            let updated = try await commentViewModel.likeAndReturn(comment: comment, isPositive: isPositive)
            if displayedComment.id == comment.id {
                displayedComment = updated
            }
            if case .loaded(let snapshot) = state {
                state = .loaded(snapshot.updatingComment(id: comment.id, with: updated))
            }
        } catch {
            commentViewModel.actionMessage = ErrorMessage.userFriendly(error)
        }
    }

    func report(comment: CommentRow, reason: ReportReasonRow) {
        commentViewModel.report(comment: comment, reason: reason)
    }
}

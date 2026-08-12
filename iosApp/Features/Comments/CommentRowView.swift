import SwiftUI

struct CommentRowView: View {
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

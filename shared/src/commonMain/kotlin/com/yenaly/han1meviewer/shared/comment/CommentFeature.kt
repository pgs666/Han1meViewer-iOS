package com.yenaly.han1meviewer.shared.comment

import com.yenaly.han1meviewer.shared.model.CommentPlace
import com.yenaly.han1meviewer.shared.model.CommentTargetType
import com.yenaly.han1meviewer.shared.model.VideoComment
import com.yenaly.han1meviewer.shared.repository.CommentRepository
import kotlinx.serialization.Serializable

class CommentFeature(
    private val repository: CommentRepository,
) {
    @Throws(Exception::class)
    suspend fun loadVideoComments(videoCode: String): CommentThreadSnapshot {
        return repository.getComments(CommentTargetType.Video, videoCode).toSnapshot()
    }

    @Throws(Exception::class)
    suspend fun loadReplies(commentId: String): CommentThreadSnapshot {
        return repository.getCommentReplies(commentId).toSnapshot()
    }

    @Throws(Exception::class)
    suspend fun postVideoComment(
        videoCode: String,
        currentUserId: String,
        csrfToken: String?,
        text: String,
    ) {
        repository.postComment(
            csrfToken = csrfToken,
            currentUserId = currentUserId,
            targetId = videoCode,
            type = CommentTargetType.Video,
            text = text,
        )
    }

    @Throws(Exception::class)
    suspend fun postReply(
        replyCommentId: String,
        csrfToken: String?,
        text: String,
    ) {
        repository.postReply(
            csrfToken = csrfToken,
            replyCommentId = replyCommentId,
            text = text,
        )
    }

    @Throws(Exception::class)
    suspend fun likeComment(
        csrfToken: String?,
        comment: CommentSnapshot,
        isPositive: Boolean,
    ): CommentSnapshot {
        val model = comment.toModel()
        repository.likeComment(
            csrfToken = csrfToken,
            place = if (comment.isChildComment) CommentPlace.ChildComment else CommentPlace.Comment,
            isPositive = isPositive,
            comment = model,
        )
        return model.withLikeResult(isPositive).toSnapshot()
    }

    @Throws(Exception::class)
    suspend fun reportComment(
        currentUserId: String?,
        csrfToken: String?,
        redirectUrl: String,
        comment: CommentSnapshot,
        reason: String,
    ) {
        repository.reportComment(
            userId = currentUserId,
            csrfToken = csrfToken,
            redirectUrl = redirectUrl,
            reportableId = comment.reportableId,
            reportableType = comment.reportableType,
            reason = reason,
        )
    }

    fun reportReasonCount(): Int = DEFAULT_REPORT_REASONS.size

    fun reportReasonAt(index: Int): ReportReasonSnapshot? = DEFAULT_REPORT_REASONS.getOrNull(index)
}

@Serializable
data class CommentThreadSnapshot(
    val currentUserId: String?,
    val csrfToken: String?,
    private val comments: List<CommentSnapshot>,
) {
    fun commentCount(): Int = comments.size

    fun commentAt(index: Int): CommentSnapshot? = comments.getOrNull(index)
}

@Serializable
data class CommentSnapshot(
    val stableKey: String,
    val avatarUrl: String,
    val username: String,
    val date: String,
    val content: String,
    val thumbUp: Int?,
    val isChildComment: Boolean,
    val hasMoreReplies: Boolean,
    val replyCount: Int?,
    val id: String?,
    val replyTargetId: String?,
    val foreignId: String?,
    val isPositive: Boolean,
    val likeUserId: String?,
    val commentLikesCount: Int?,
    val commentLikesSum: Int?,
    val likeCommentStatus: Boolean,
    val unlikeCommentStatus: Boolean,
    val redirectUrl: String?,
    val reportableId: String?,
    val reportableType: String?,
)

@Serializable
data class ReportReasonSnapshot(
    val title: String,
    val value: String,
)

private fun com.yenaly.han1meviewer.shared.model.VideoComments.toSnapshot(): CommentThreadSnapshot {
    return CommentThreadSnapshot(
        currentUserId = currentUserId,
        csrfToken = csrfToken,
        comments = comments.map { it.toSnapshot() },
    )
}

private fun VideoComment.toSnapshot(): CommentSnapshot {
    return CommentSnapshot(
        stableKey = stableKey,
        avatarUrl = avatarUrl,
        username = username,
        date = date,
        content = content,
        thumbUp = thumbUp,
        isChildComment = isChildComment,
        hasMoreReplies = hasMoreReplies,
        replyCount = replyCount,
        id = id,
        replyTargetId = replyTargetIdOrNull,
        foreignId = post.foreignId,
        isPositive = post.isPositive,
        likeUserId = post.likeUserId,
        commentLikesCount = post.commentLikesCount,
        commentLikesSum = post.commentLikesSum,
        likeCommentStatus = post.likeCommentStatus,
        unlikeCommentStatus = post.unlikeCommentStatus,
        redirectUrl = redirectUrl,
        reportableId = reportableId,
        reportableType = reportableType,
    )
}

private fun CommentSnapshot.toModel(): VideoComment {
    return VideoComment(
        avatarUrl = avatarUrl,
        username = username,
        date = date,
        content = content,
        thumbUp = thumbUp,
        isChildComment = isChildComment,
        hasMoreReplies = hasMoreReplies,
        replyCount = replyCount,
        id = id,
        post = com.yenaly.han1meviewer.shared.model.VideoCommentPost(
            foreignId = foreignId,
            isPositive = isPositive,
            likeUserId = likeUserId,
            commentLikesCount = commentLikesCount,
            commentLikesSum = commentLikesSum,
            likeCommentStatus = likeCommentStatus,
            unlikeCommentStatus = unlikeCommentStatus,
        ),
        redirectUrl = redirectUrl,
        reportableId = reportableId,
        reportableType = reportableType,
    )
}

private val DEFAULT_REPORT_REASONS = listOf(
    ReportReasonSnapshot(title = "煽动仇恨或恶意内容", value = "煽動仇恨或惡意內容"),
    ReportReasonSnapshot(title = "暴力或令人反感的内容", value = "暴力或令人反感的內容"),
    ReportReasonSnapshot(title = "广告内容或垃圾内容", value = "廣告內容或垃圾內容"),
    ReportReasonSnapshot(title = "其他检举理由", value = "其他檢舉理由"),
)

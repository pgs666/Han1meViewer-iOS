package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

@Serializable
enum class CommentTargetType(val value: String) {
    Video("video"),
    Preview("preview"),
}

@Serializable
enum class CommentPlace(val value: String) {
    Comment("comment"),
    ChildComment("reply"),
}

@Serializable
data class VideoComments(
    val comments: List<VideoComment>,
    @Transient
    val currentUserId: String? = null,
    @Transient
    val csrfToken: String? = null,
)

@Serializable
data class VideoComment(
    val avatarUrl: String,
    val username: String,
    val date: String,
    val content: String,
    val thumbUp: Int?,
    val isChildComment: Boolean,
    val hasMoreReplies: Boolean = false,
    val replyCount: Int? = 0,
    val id: String? = "-1",
    val post: VideoCommentPost,
    val redirectUrl: String? = null,
    val reportableId: String? = null,
    val reportableType: String? = null,
) {
    val replyTargetIdOrNull: String?
        get() = post.foreignId ?: id

    val stableKey: String
        get() = replyTargetIdOrNull
            ?: reportableId
            ?: "$username|$date|${content.hashCode()}"

    fun withLikeResult(isPositive: Boolean): VideoComment {
        val currentLikes = thumbUp ?: return this
        return if (isPositive) {
            val cancel = post.likeCommentStatus
            copy(
                thumbUp = currentLikes + if (cancel) -1 else 1,
                post = post.copy(
                    isPositive = true,
                    likeCommentStatus = !cancel,
                    unlikeCommentStatus = false,
                ),
            )
        } else {
            val cancel = post.unlikeCommentStatus
            copy(
                thumbUp = currentLikes - if (cancel) -1 else 1,
                post = post.copy(
                    isPositive = false,
                    likeCommentStatus = false,
                    unlikeCommentStatus = !cancel,
                ),
            )
        }
    }
}

@Serializable
data class VideoCommentPost(
    val foreignId: String? = null,
    val isPositive: Boolean = false,
    val likeUserId: String? = null,
    val commentLikesCount: Int? = null,
    val commentLikesSum: Int? = null,
    val likeCommentStatus: Boolean = false,
    val unlikeCommentStatus: Boolean = false,
)

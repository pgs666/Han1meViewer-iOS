package com.yenaly.han1meviewer.shared.comment

import com.yenaly.han1meviewer.shared.model.CommentPlace
import com.yenaly.han1meviewer.shared.model.CommentTargetType
import com.yenaly.han1meviewer.shared.model.VideoComment
import com.yenaly.han1meviewer.shared.model.VideoCommentPost
import com.yenaly.han1meviewer.shared.model.VideoComments
import com.yenaly.han1meviewer.shared.repository.CommentRepository
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class CommentFeatureTest {
    @Test
    fun loadVideoCommentsExposesThreadSnapshot() = runTest {
        val repository = FakeCommentRepository()
        val feature = CommentFeature(repository)

        val snapshot = feature.loadVideoComments("12345")

        assertEquals(CommentTargetType.Video, repository.lastCommentType)
        assertEquals("12345", repository.lastCommentCode)
        assertEquals("42", snapshot.currentUserId)
        assertEquals("csrf-comment", snapshot.csrfToken)
        assertEquals(1, snapshot.commentCount())
        assertEquals("Alice", snapshot.commentAt(0)?.username)
    }

    @Test
    fun likeCommentSendsCorrectPlaceAndReturnsUpdatedPositiveState() = runTest {
        val repository = FakeCommentRepository()
        val feature = CommentFeature(repository)
        val comment = feature.loadVideoComments("12345").commentAt(0)

        val updated = feature.likeComment(
            csrfToken = "csrf-comment",
            comment = assertNotNull(comment),
            isPositive = true,
        )

        assertEquals(CommentPlace.Comment, repository.lastLikePlace)
        assertEquals(true, repository.lastLikeIsPositive)
        assertEquals("foreign-99", repository.lastLikedComment?.post?.foreignId)
        assertEquals(4, updated.thumbUp)
        assertTrue(updated.likeCommentStatus)
        assertFalse(updated.unlikeCommentStatus)
    }

    @Test
    fun dislikeChildCommentSendsReplyPlaceAndReturnsUpdatedNegativeState() = runTest {
        val repository = FakeCommentRepository()
        val feature = CommentFeature(repository)
        val reply = feature.loadReplies("99").commentAt(0)

        val updated = feature.likeComment(
            csrfToken = "csrf-comment",
            comment = assertNotNull(reply),
            isPositive = false,
        )

        assertEquals(CommentPlace.ChildComment, repository.lastLikePlace)
        assertEquals(false, repository.lastLikeIsPositive)
        assertEquals("reply-100", repository.lastLikedComment?.post?.foreignId)
        assertEquals(1, updated.thumbUp)
        assertFalse(updated.likeCommentStatus)
        assertTrue(updated.unlikeCommentStatus)
    }

    @Test
    fun postReplyAndReportForwardExpectedParameters() = runTest {
        val repository = FakeCommentRepository()
        val feature = CommentFeature(repository)
        val comment = feature.loadVideoComments("12345").commentAt(0)

        feature.postReply(replyCommentId = "99", csrfToken = "csrf-comment", text = "reply body")
        feature.reportComment(
            currentUserId = "42",
            csrfToken = "csrf-comment",
            redirectUrl = "https://hanime1.me/watch?v=12345",
            comment = assertNotNull(comment),
            reason = "廣告內容或垃圾內容",
        )

        assertEquals("99", repository.lastReplyCommentId)
        assertEquals("reply body", repository.lastReplyText)
        assertEquals("42", repository.lastReportUserId)
        assertEquals("report-99", repository.lastReportableId)
        assertEquals("comment", repository.lastReportableType)
        assertEquals("廣告內容或垃圾內容", repository.lastReportReason)
    }

    @Test
    fun reportReasonsMatchAndroidReasonKeys() {
        val feature = CommentFeature(FakeCommentRepository())

        assertEquals(4, feature.reportReasonCount())
        assertEquals("煽動仇恨或惡意內容", feature.reportReasonAt(0)?.value)
        assertEquals("暴力或令人反感的內容", feature.reportReasonAt(1)?.value)
        assertEquals("廣告內容或垃圾內容", feature.reportReasonAt(2)?.value)
        assertEquals("其他檢舉理由", feature.reportReasonAt(3)?.value)
    }

    private class FakeCommentRepository : CommentRepository {
        var lastCommentType: CommentTargetType? = null
        var lastCommentCode: String? = null
        var lastLikePlace: CommentPlace? = null
        var lastLikeIsPositive: Boolean? = null
        var lastLikedComment: VideoComment? = null
        var lastReplyCommentId: String? = null
        var lastReplyText: String? = null
        var lastReportUserId: String? = null
        var lastReportableId: String? = null
        var lastReportableType: String? = null
        var lastReportReason: String? = null

        override suspend fun getComments(type: CommentTargetType, code: String): VideoComments {
            lastCommentType = type
            lastCommentCode = code
            return VideoComments(
                comments = listOf(parentComment()),
                currentUserId = "42",
                csrfToken = "csrf-comment",
            )
        }

        override suspend fun getCommentReplies(commentId: String): VideoComments {
            return VideoComments(comments = listOf(childComment()))
        }

        override suspend fun postComment(
            csrfToken: String?,
            currentUserId: String,
            targetId: String,
            type: CommentTargetType,
            text: String,
        ) = Unit

        override suspend fun postReply(
            csrfToken: String?,
            replyCommentId: String,
            text: String,
        ) {
            lastReplyCommentId = replyCommentId
            lastReplyText = text
        }

        override suspend fun likeComment(
            csrfToken: String?,
            place: CommentPlace,
            isPositive: Boolean,
            comment: VideoComment,
        ) {
            lastLikePlace = place
            lastLikeIsPositive = isPositive
            lastLikedComment = comment
        }

        override suspend fun reportComment(
            userId: String?,
            csrfToken: String?,
            redirectUrl: String,
            reportableId: String?,
            reportableType: String?,
            reason: String,
        ) {
            lastReportUserId = userId
            lastReportableId = reportableId
            lastReportableType = reportableType
            lastReportReason = reason
        }

        private fun parentComment(): VideoComment {
            return VideoComment(
                avatarUrl = "https://img.example/avatar.jpg",
                username = "Alice",
                date = "5分鐘前",
                content = "Nice",
                thumbUp = 3,
                isChildComment = false,
                hasMoreReplies = true,
                replyCount = 1,
                id = "99",
                post = VideoCommentPost(
                    foreignId = "foreign-99",
                    likeUserId = "42",
                    commentLikesCount = 3,
                    commentLikesSum = 3,
                ),
                reportableId = "report-99",
                reportableType = "comment",
            )
        }

        private fun childComment(): VideoComment {
            return VideoComment(
                avatarUrl = "https://img.example/reply-avatar.jpg",
                username = "Bob",
                date = "1分鐘前",
                content = "@Alice reply",
                thumbUp = 2,
                isChildComment = true,
                post = VideoCommentPost(
                    foreignId = "reply-100",
                    likeUserId = "42",
                    commentLikesCount = 2,
                    commentLikesSum = 2,
                ),
                reportableId = "report-100",
                reportableType = "reply",
            )
        }
    }
}

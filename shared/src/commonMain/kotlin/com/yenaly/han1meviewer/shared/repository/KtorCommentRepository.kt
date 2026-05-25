package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.CommentPlace
import com.yenaly.han1meviewer.shared.model.CommentTargetType
import com.yenaly.han1meviewer.shared.model.VideoComment
import com.yenaly.han1meviewer.shared.model.VideoComments
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import com.yenaly.han1meviewer.shared.session.SessionStore
import io.ktor.client.HttpClient
import io.ktor.client.request.forms.submitForm
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.Url
import io.ktor.http.parameters

class KtorCommentRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : CommentRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, Url(baseUrl).host)

    override suspend fun getComments(type: CommentTargetType, code: String): VideoComments {
        val response = client.get("$baseUrl/loadComment") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "application/json, text/javascript, */*; q=0.01")
            header("X-Requested-With", "XMLHttpRequest")
            parameter("type", type.value)
            parameter("id", code)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)
        return parser.parseComments(response.bodyAsText())
    }

    override suspend fun getCommentReplies(commentId: String): VideoComments {
        val response = client.get("$baseUrl/loadReplies") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "application/json, text/javascript, */*; q=0.01")
            header("X-Requested-With", "XMLHttpRequest")
            parameter("id", commentId)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)
        return parser.parseCommentReplies(response.bodyAsText())
    }

    override suspend fun postComment(
        csrfToken: String?,
        currentUserId: String,
        targetId: String,
        type: CommentTargetType,
        text: String,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/createComment",
            formParameters = parameters {
                append("_token", csrfToken.orEmpty())
                append("comment-user-id", currentUserId)
                append("comment-type", type.value)
                append("comment-foreign-id", targetId)
                append("comment-text", text)
                append("comment-count", "1")
                append("comment-is-political", "0")
            },
        ) {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", csrfToken.orEmpty())
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
    }

    override suspend fun postReply(
        csrfToken: String?,
        replyCommentId: String,
        text: String,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/replyComment",
            formParameters = parameters {
                append("_token", csrfToken.orEmpty())
                append("reply-comment-id", replyCommentId)
                append("reply-comment-text", text)
            },
        ) {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", csrfToken.orEmpty())
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
    }

    override suspend fun likeComment(
        csrfToken: String?,
        place: CommentPlace,
        isPositive: Boolean,
        comment: VideoComment,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/commentLike",
            formParameters = parameters {
                append("_token", csrfToken.orEmpty())
                append("foreign_type", place.value)
                append("foreign_id", comment.post.foreignId.orEmpty())
                append("is_positive", if (isPositive) "1" else "0")
                append("comment-like-user-id", comment.post.likeUserId.orEmpty())
                append("comment-likes-count", (comment.post.commentLikesCount ?: 0).toString())
                append("comment-likes-sum", (comment.post.commentLikesSum ?: 0).toString())
                append("like-comment-status", if (comment.post.likeCommentStatus) "1" else "0")
                append("unlike-comment-status", if (comment.post.unlikeCommentStatus) "1" else "0")
            },
        ) {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", csrfToken.orEmpty())
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
    }

    override suspend fun reportComment(
        userId: String?,
        csrfToken: String?,
        redirectUrl: String,
        reportableId: String?,
        reportableType: String?,
        reason: String,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/user/${userId.orEmpty()}/report",
            formParameters = parameters {
                append("_token", csrfToken.orEmpty())
                append("redirect-url", redirectUrl)
                append("reportable-id", reportableId.orEmpty())
                append("reportable-type", reportableType.orEmpty())
                append("reason", reason)
            },
        ) {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", csrfToken.orEmpty())
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

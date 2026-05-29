package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.CommentTargetType
import com.yenaly.han1meviewer.shared.network.testHttpClient
import com.yenaly.han1meviewer.shared.session.MemorySessionStore
import com.yenaly.han1meviewer.shared.test.runTest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class CsrfRetryTest {
    @Test
    fun postCommentRetriesWithFreshTokenOn419() = runTest {
        val tokens = mutableListOf<String>()
        var call = 0
        val engine = MockEngine { request ->
            when {
                request.url.encodedPath.endsWith("/createComment") -> {
                    tokens += (request.body as? OutgoingContent.ByteArrayContent)
                        ?.bytes()?.decodeToString()
                        ?.substringAfter("_token=")?.substringBefore("&")
                        .orEmpty()
                    call++
                    if (call == 1) respond("expired", HttpStatusCode(419, "Page Expired"))
                    else respond("ok", HttpStatusCode.OK)
                }
                // refreshToken GET: serve a page carrying a fresh _token.
                else -> respond(
                    "<html><body><input name=\"_token\" value=\"fresh-token\"></body></html>",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "text/html"),
                )
            }
        }
        val repo = KtorCommentRepository(
            sessionStore = MemorySessionStore(),
            client = testHttpClient(engine),
        )

        repo.postComment(
            csrfToken = "stale-token",
            currentUserId = "42",
            targetId = "12345",
            type = CommentTargetType.Video,
            text = "hi",
        )

        assertEquals(2, tokens.size, "expected an initial attempt + one retry")
        assertEquals("stale-token", tokens[0])
        assertEquals("fresh-token", tokens[1])
    }

    @Test
    fun postCommentSucceedsOnFirstTryWithoutRefresh() = runTest {
        var createCalls = 0
        var refreshCalls = 0
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("/createComment")) {
                createCalls++
                respond("ok", HttpStatusCode.OK)
            } else {
                refreshCalls++
                respond("", HttpStatusCode.OK)
            }
        }
        val repo = KtorCommentRepository(
            sessionStore = MemorySessionStore(),
            client = testHttpClient(engine),
        )

        repo.postComment(
            csrfToken = "good-token",
            currentUserId = "42",
            targetId = "12345",
            type = CommentTargetType.Video,
            text = "hi",
        )

        assertEquals(1, createCalls)
        assertTrue(refreshCalls == 0, "no token refresh expected on success")
    }
}

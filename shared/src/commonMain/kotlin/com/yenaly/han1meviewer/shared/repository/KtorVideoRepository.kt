package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker.hasConfirmedLogin
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import com.yenaly.han1meviewer.shared.session.SessionStore
import io.ktor.client.HttpClient
import io.ktor.client.request.forms.submitForm
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.parameters

class KtorVideoRepository(
    private val sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    client: HttpClient? = null,
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : VideoRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl)
    private val client: HttpClient = client ?: createHan1meHttpClient(saveCookies = cookieBridge::saveResponseCookies, isAlreadyLogin = { sessionStore.loadCookies().hasConfirmedLogin() })

    override suspend fun getVideo(videoCode: String): HanimeVideo {
        val response = client.get("$baseUrl/watch?v=$videoCode") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to load video.")

        return parser.parseVideo(response.bodyAsText(), videoCode)
    }

    override suspend fun setFavorite(
        videoCode: String,
        userId: String?,
        csrfToken: String?,
        isFavorite: Boolean,
    ) {
        val initialToken = requireMutationCsrfToken(csrfToken)
        val currentUserId = requireMutationUserId(userId)

        suspend fun submitFavorite(token: String): HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.submitForm(
                url = "$baseUrl/like",
                formParameters = parameters {
                    append("like-foreign-id", videoCode)
                    append("like-status", if (isFavorite) "" else "1")
                    append("_token", token)
                    append("like-user-id", currentUserId)
                    append("like-is-positive", "1")
                },
            ) {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header("X-CSRF-TOKEN", token)
                cookieHeader?.let { header(HttpHeaders.Cookie, it) }
            }
        }

        val response = submitMutationWithCsrfRetry(
            initialToken = initialToken,
            refreshToken = { fetchFreshCsrfTokenAt("$baseUrl/watch?v=$videoCode") },
            submit = ::submitFavorite,
        )
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to update favorite state.")
    }

    override suspend fun setMyListItem(
        listCode: String,
        videoCode: String,
        csrfToken: String?,
        isSelected: Boolean,
    ) {
        val initialToken = requireMutationCsrfToken(csrfToken)

        suspend fun submitListItem(token: String): HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.submitForm(
                url = "$baseUrl/save",
                formParameters = parameters {
                    append("_token", token)
                    append("input_id", listCode)
                    append("video_id", videoCode)
                    append("is_checked", isSelected.toString())
                    append("user_id", "")
                },
            ) {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header("X-CSRF-TOKEN", token)
                cookieHeader?.let { header(HttpHeaders.Cookie, it) }
            }
        }

        val response = submitMutationWithCsrfRetry(
            initialToken = initialToken,
            refreshToken = { fetchFreshCsrfTokenAt("$baseUrl/watch?v=$videoCode") },
            submit = ::submitListItem,
        )
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to update list state.")
    }

    override suspend fun setArtistSubscription(
        userId: String,
        artistId: String,
        csrfToken: String?,
        isSubscribed: Boolean,
    ) {
        val initialToken = requireMutationCsrfToken(csrfToken)

        suspend fun submitSubscription(token: String): HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.submitForm(
                url = "$baseUrl/subscribe",
                formParameters = parameters {
                    append("_token", token)
                    append("subscribe-user-id", userId)
                    append("subscribe-artist-id", artistId)
                    append("subscribe-status", if (isSubscribed) "" else "1")
                },
            ) {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header("X-CSRF-TOKEN", token)
                cookieHeader?.let { header(HttpHeaders.Cookie, it) }
            }
        }

        val response = submitMutationWithCsrfRetry(
            initialToken = initialToken,
            refreshToken = { fetchFreshCsrfTokenAt(baseUrl) },
            submit = ::submitSubscription,
        )
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to update artist subscription.")
    }

    /// Fetches `pageUrl` solely to (a) refresh cookies (the server rotates
    /// XSRF-TOKEN / laravel_session as part of its security model) and
    /// (b) extract a fresh `_token` for retrying a mutation that just
    /// returned 419. Per-mutation choice of pageUrl is important — for
    /// per-video mutations (favorite, save-to-list) we hit the actual
    /// /watch?v=<code> page so the new token belongs to the same logical
    /// session the user is currently looking at; for cross-page mutations
    /// (artist subscribe) we fall back to the home page. Returns null if
    /// the page itself fails to load — caller surfaces the original 419
    /// to the user.
    private suspend fun fetchFreshCsrfTokenAt(pageUrl: String): String? {
        return try {
            val response = client.get(pageUrl) {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
                cookieBridge.applyStoredCookies(this)
            }
            cookieBridge.saveResponseCookies(response)
            if (response.status.value !in 200..299) return null
            parser.extractCsrfToken(response.bodyAsText())
        } catch (_: Exception) {
            null
        }
    }
}

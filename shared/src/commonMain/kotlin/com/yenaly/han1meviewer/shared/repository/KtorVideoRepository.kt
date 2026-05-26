package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import com.yenaly.han1meviewer.shared.session.SessionStore
import io.ktor.client.HttpClient
import io.ktor.client.request.forms.submitForm
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.parameters

class KtorVideoRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : VideoRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl)

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
        val token = requireMutationCsrfToken(csrfToken)
        val currentUserId = requireMutationUserId(userId)
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
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
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to update favorite state.")
    }

    override suspend fun setMyListItem(
        listCode: String,
        videoCode: String,
        csrfToken: String?,
        isSelected: Boolean,
    ) {
        val token = requireMutationCsrfToken(csrfToken)
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
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
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to update list state.")
    }

    override suspend fun setArtistSubscription(
        userId: String,
        artistId: String,
        csrfToken: String?,
        isSubscribed: Boolean,
    ) {
        val token = requireMutationCsrfToken(csrfToken)
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
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
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to update artist subscription.")
    }
}

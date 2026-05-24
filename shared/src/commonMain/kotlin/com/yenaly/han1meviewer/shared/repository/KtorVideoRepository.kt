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
import io.ktor.http.Url
import io.ktor.http.parameters

class KtorVideoRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : VideoRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, Url(baseUrl).host)

    override suspend fun getVideo(videoCode: String): HanimeVideo {
        val response = client.get("$baseUrl/watch?v=$videoCode") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseVideo(response.bodyAsText(), videoCode)
    }

    override suspend fun setFavorite(
        videoCode: String,
        userId: String?,
        csrfToken: String?,
        isFavorite: Boolean,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/like",
            formParameters = parameters {
                append("like-foreign-id", videoCode)
                append("like-status", if (isFavorite) "" else "1")
                append("_token", csrfToken.orEmpty())
                append("like-user-id", userId.orEmpty())
                append("like-is-positive", "1")
            },
        ) {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", csrfToken.orEmpty())
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
    }

    override suspend fun setMyListItem(
        listCode: String,
        videoCode: String,
        csrfToken: String?,
        isSelected: Boolean,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/save",
            formParameters = parameters {
                append("_token", csrfToken.orEmpty())
                append("input_id", listCode)
                append("video_id", videoCode)
                append("is_checked", isSelected.toString())
                append("user_id", "")
            },
        ) {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", csrfToken.orEmpty())
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
    }

    override suspend fun setArtistSubscription(
        userId: String,
        artistId: String,
        csrfToken: String?,
        isSubscribed: Boolean,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/subscribe",
            formParameters = parameters {
                append("_token", csrfToken.orEmpty())
                append("subscribe-user-id", userId)
                append("subscribe-artist-id", artistId)
                append("subscribe-status", if (isSubscribed) "" else "1")
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

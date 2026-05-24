package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.model.UserVideoListPage
import com.yenaly.han1meviewer.shared.model.UserVideoListType
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

class KtorUserVideoListRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : UserVideoListRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, Url(baseUrl).host)

    override suspend fun getUserVideoList(
        userId: String,
        type: UserVideoListType,
        page: Int,
    ): UserVideoListPage {
        val response = client.get("$baseUrl/user/$userId/${type.path}") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseUserVideoList(response.bodyAsText(), page)
    }

    override suspend fun getPlaylistVideos(listCode: String, page: Int): UserVideoListPage {
        val response = client.get("$baseUrl/playlist") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("list", listCode)
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseUserVideoList(response.bodyAsText(), page)
    }

    override suspend fun removeUserVideoListItem(
        userId: String,
        type: UserVideoListType,
        videoCode: String,
        csrfToken: String?,
    ) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = when (type) {
            UserVideoListType.WatchLater -> {
                client.submitForm(
                    url = "$baseUrl/save",
                    formParameters = parameters {
                        append("_token", csrfToken.orEmpty())
                        append("input_id", "save")
                        append("video_id", videoCode)
                        append("is_checked", "false")
                        append("user_id", "")
                    },
                ) {
                    header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
                    header("X-CSRF-TOKEN", csrfToken.orEmpty())
                    cookieHeader?.let { header(HttpHeaders.Cookie, it) }
                }
            }

            UserVideoListType.Favorites -> {
                val video = getVideoForMutation(videoCode)
                if (!video.isFav) return

                client.submitForm(
                    url = "$baseUrl/like",
                    formParameters = parameters {
                        append("like-foreign-id", videoCode)
                        append("like-status", "1")
                        append("_token", (video.csrfToken ?: csrfToken).orEmpty())
                        append("like-user-id", video.currentUserId ?: userId)
                        append("like-is-positive", "1")
                    },
                ) {
                    header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
                    header("X-CSRF-TOKEN", (video.csrfToken ?: csrfToken).orEmpty())
                    cookieHeader?.let { header(HttpHeaders.Cookie, it) }
                }
            }
        }
        cookieBridge.saveResponseCookies(response)
    }

    private suspend fun getVideoForMutation(videoCode: String): HanimeVideo {
        val response = client.get("$baseUrl/watch?v=$videoCode") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseVideo(response.bodyAsText(), videoCode)
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

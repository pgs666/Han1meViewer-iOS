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
import io.ktor.http.parameters

class KtorUserVideoListRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : UserVideoListRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl)

    override suspend fun getUserVideoList(
        userId: String,
        type: UserVideoListType,
        page: Int,
    ): UserVideoListPage {
        val response = client.get("$baseUrl/user/$userId/${type.path}") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseUserVideoList(response.bodyAsText(), page)
    }

    override suspend fun getPlaylistVideos(listCode: String, page: Int): UserVideoListPage {
        val response = client.get("$baseUrl/playlist") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
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
        val token = requireMutationCsrfToken(csrfToken)
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = when (type) {
            UserVideoListType.WatchLater -> {
                client.submitForm(
                    url = "$baseUrl/save",
                    formParameters = parameters {
                        append("_token", token)
                        append("input_id", "save")
                        append("video_id", videoCode)
                        append("is_checked", "false")
                        append("user_id", "")
                    },
                ) {
                    header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                    header("X-CSRF-TOKEN", token)
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
                        append("_token", video.csrfToken ?: token)
                        append("like-user-id", video.currentUserId ?: userId)
                        append("like-is-positive", "1")
                    },
                ) {
                    header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                    header("X-CSRF-TOKEN", video.csrfToken ?: token)
                    cookieHeader?.let { header(HttpHeaders.Cookie, it) }
                }
            }
        }
        cookieBridge.saveResponseCookies(response)
    }

    private suspend fun getVideoForMutation(videoCode: String): HanimeVideo {
        val response = client.get("$baseUrl/watch?v=$videoCode") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseVideo(response.bodyAsText(), videoCode)
    }
}

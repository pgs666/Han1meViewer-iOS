package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.UserPlaylistPage
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
import io.ktor.client.request.parameter
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.parameters

class KtorUserPlaylistRepository(
    private val sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    client: HttpClient? = null,
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : UserPlaylistRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl)
    private val client: HttpClient = client ?: createHan1meHttpClient(saveCookies = cookieBridge::saveResponseCookies, isAlreadyLogin = { sessionStore.loadCookies().hasConfirmedLogin() })

    override suspend fun getPlaylists(userId: String, page: Int): UserPlaylistPage {
        val response = client.get("$baseUrl/user/$userId/playlists") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseUserPlaylists(response.bodyAsText(), page)
    }

    override suspend fun createPlaylist(
        csrfToken: String?,
        videoCode: String,
        title: String,
        description: String,
    ) {
        val token = requireMutationCsrfToken(csrfToken)
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/createPlaylist",
            formParameters = parameters {
                append("_token", token)
                append("create-playlist-video-id", videoCode)
                append("playlist-title", title)
                append("playlist-description", description)
            },
        ) {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", token)
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to create playlist.")
    }

    override suspend fun modifyPlaylist(
        listCode: String,
        title: String,
        description: String,
        delete: Boolean,
        csrfToken: String?,
    ) {
        val token = requireMutationCsrfToken(csrfToken)
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.submitForm(
            url = "$baseUrl/playlist/$listCode",
            formParameters = parameters {
                append("_token", token)
                append("_method", "PUT")
                append("playlist-title", title)
                append("playlist-description", description)
                if (delete) {
                    append("playlist-delete", "on")
                }
            },
        ) {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header("X-CSRF-TOKEN", token)
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
        }
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to modify playlist.")
    }
}

package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.UserPlaylistPage
import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
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
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.parameters

class KtorUserPlaylistRepository(
    private val sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    client: HttpClient? = null,
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
    private val videoLanguageProvider: () -> String = { "zht" },
) : UserPlaylistRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl, videoLanguageProvider)
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

        suspend fun submit(csrf: String): HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.submitForm(
                url = "$baseUrl/createPlaylist",
                formParameters = parameters {
                    append("_token", csrf)
                    append("create-playlist-video-id", videoCode)
                    append("playlist-title", title)
                    append("playlist-description", description)
                },
            ) {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header("X-CSRF-TOKEN", csrf)
                cookieHeader?.let { header(HttpHeaders.Cookie, it) }
            }
        }

        val response = try {
            submitMutationWithCsrfRetry(
                initialToken = token,
                refreshToken = { fetchFreshCsrfTokenAt(client, cookieBridge, parser, "$baseUrl/watch?v=$videoCode") },
                submit = ::submit,
            )
        } catch (e: DomainException) {
            // Android (NetworkRepo.createPlaylist, permittedSuccessCode=500)
            // treats HTTP 500 as success — the server returns 500 even on a
            // successful create. The shared client's validator surfaces 5xx
            // as DomainError.Network, so swallow exactly the 500 case.
            if ((e.error as? DomainError.Network)?.statusCode == 500) return
            throw e
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

        suspend fun submit(csrf: String): HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.submitForm(
                url = "$baseUrl/playlist/$listCode",
                formParameters = parameters {
                    append("_token", csrf)
                    append("_method", "PUT")
                    append("playlist-title", title)
                    append("playlist-description", description)
                    if (delete) {
                        append("playlist-delete", "on")
                    }
                },
            ) {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header("X-CSRF-TOKEN", csrf)
                cookieHeader?.let { header(HttpHeaders.Cookie, it) }
            }
        }

        val response = submitMutationWithCsrfRetry(
            initialToken = token,
            refreshToken = { fetchFreshCsrfTokenAt(client, cookieBridge, parser, baseUrl) },
            submit = ::submit,
        )
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to modify playlist.")
    }
}

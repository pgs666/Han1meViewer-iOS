package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.UserPlaylistPage
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import com.yenaly.han1meviewer.shared.session.SessionStore
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders

class KtorUserPlaylistRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : UserPlaylistRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl)

    override suspend fun getPlaylists(userId: String, page: Int): UserPlaylistPage {
        val response = client.get("$baseUrl/user/$userId/playlists") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseUserPlaylists(response.bodyAsText(), page)
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import com.yenaly.han1meviewer.shared.session.SessionStore
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders

class KtorHomeRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : HomeRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl)

    override suspend fun getHomePage(): HomePage {
        val response = client.get(baseUrl) {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseHome(response.bodyAsText())
    }
}

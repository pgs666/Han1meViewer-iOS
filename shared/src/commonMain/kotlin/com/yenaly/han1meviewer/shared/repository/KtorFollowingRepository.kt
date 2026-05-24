package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.MySubscriptions
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
import io.ktor.http.Url

class KtorFollowingRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : FollowingRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, Url(baseUrl).host)

    override suspend fun getSubscriptions(page: Int): MySubscriptions {
        val response = client.get("$baseUrl/subscriptions") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseSubscriptions(response.bodyAsText())
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

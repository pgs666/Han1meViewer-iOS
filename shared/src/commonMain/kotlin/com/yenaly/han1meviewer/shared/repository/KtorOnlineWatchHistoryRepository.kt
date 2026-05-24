package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.OnlineWatchHistorySort
import com.yenaly.han1meviewer.shared.model.UserVideoListPage
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import com.yenaly.han1meviewer.shared.session.SessionStore
import io.ktor.client.HttpClient
import io.ktor.client.request.delete
import io.ktor.client.request.forms.FormDataContent
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.Url
import io.ktor.http.parameters
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class KtorOnlineWatchHistoryRepository(
    sessionStore: SessionStore,
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : OnlineWatchHistoryRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, Url(baseUrl).host)

    override suspend fun getHistories(
        userId: String,
        sort: OnlineWatchHistorySort,
        page: Int,
    ): UserVideoListPage {
        val response = client.get("$baseUrl/user/$userId/histories") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("sort", sort.value)
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseUserVideoList(response.bodyAsText(), page)
    }

    override suspend fun removeHistoryItem(videoCode: String, csrfToken: String?) {
        val cookieHeader = cookieBridge.storedCookieHeader()
        val response = client.delete("$baseUrl/user/tab-item/$videoCode") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "application/json, text/plain, */*")
            header("X-CSRF-TOKEN", csrfToken.orEmpty())
            cookieHeader?.let { header(HttpHeaders.Cookie, it) }
            setBody(FormDataContent(parameters { append("tab", "histories") }))
        }
        cookieBridge.saveResponseCookies(response)

        val success = Json.parseToJsonElement(response.bodyAsText())
            .jsonObject["success"]
            ?.jsonPrimitive
            ?.booleanOrNull == true
        check(success) { "Failed to delete online watch history item." }
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

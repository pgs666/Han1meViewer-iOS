package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.OnlineWatchHistorySort
import com.yenaly.han1meviewer.shared.model.UserVideoListPage
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker.hasConfirmedLogin
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import io.ktor.http.parameters
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class KtorOnlineWatchHistoryRepository(
    private val sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    client: HttpClient? = null,
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
    private val videoLanguageProvider: () -> String = { "zht" },
) : OnlineWatchHistoryRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl, videoLanguageProvider)
    private val client: HttpClient = client ?: createHan1meHttpClient(saveCookies = cookieBridge::saveResponseCookies, isAlreadyLogin = { sessionStore.loadCookies().hasConfirmedLogin() })

    override suspend fun getHistories(
        userId: String,
        sort: OnlineWatchHistorySort,
        page: Int,
    ): UserVideoListPage {
        val response = client.get("$baseUrl/user/$userId/histories") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("sort", sort.value)
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        val body = response.bodyAsText()
        return withContext(Dispatchers.Default) { parser.parseUserVideoList(body, page) }
    }

    override suspend fun removeHistoryItem(videoCode: String, csrfToken: String?) {
        val token = requireMutationCsrfToken(csrfToken)

        suspend fun submit(csrf: String): io.ktor.client.statement.HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.delete("$baseUrl/user/tab-item/$videoCode") {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header(HttpHeaders.Accept, "application/json, text/plain, */*")
                header("X-CSRF-TOKEN", csrf)
                cookieHeader?.let { header(HttpHeaders.Cookie, it) }
                setBody(FormDataContent(parameters { append("tab", "histories") }))
            }
        }

        val response = submitMutationWithCsrfRetry(
            initialToken = token,
            refreshToken = { fetchFreshCsrfTokenAt(client, cookieBridge, parser, baseUrl) },
            submit = ::submit,
        )
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to delete online watch history item.")

        val success = runCatching {
            Json.parseToJsonElement(response.bodyAsText())
                .jsonObject["success"]
                ?.jsonPrimitive
                ?.booleanOrNull == true
        }.getOrDefault(false)
        if (!success) {
            throwMutationFailure("Failed to delete online watch history item.")
        }
    }
}

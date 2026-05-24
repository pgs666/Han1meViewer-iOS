package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.network.setCookieHeaders
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.header
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpHeaders

internal class KtorCookieBridge(
    private val sessionStore: SessionStore,
    private val domain: String,
) {
    private val cookieHeaderProvider = CookieHeaderProvider(sessionStore)

    suspend fun storedCookieHeader(): String? {
        return cookieHeaderProvider.buildCookieHeader(domain)
    }

    suspend fun applyStoredCookies(builder: HttpRequestBuilder) {
        storedCookieHeader()?.let { cookieHeader ->
            builder.header(HttpHeaders.Cookie, cookieHeader)
        }
    }

    suspend fun saveResponseCookies(response: HttpResponse) {
        val cookies: List<SessionCookie> = SetCookieParser.parseAll(
            headers = response.headers.setCookieHeaders(),
            fallbackDomain = domain,
        )
        cookieHeaderProvider.saveResponseCookies(cookies)
    }
}

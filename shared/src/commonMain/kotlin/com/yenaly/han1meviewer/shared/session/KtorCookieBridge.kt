package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.network.setCookieHeaders
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.header
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpHeaders
import io.ktor.http.Url

internal class KtorCookieBridge(
    private val sessionStore: SessionStore,
    baseUrl: String,
) {
    private val url = Url(baseUrl)
    private val domain = url.host
    private val isSecureTransport = url.protocol.name.equals("https", ignoreCase = true)
    private val cookieHeaderProvider = CookieHeaderProvider(sessionStore)

    suspend fun storedCookieHeader(): String? {
        return cookieHeaderProvider.buildCookieHeader(domain, "/", isSecureTransport)
    }

    suspend fun applyStoredCookies(builder: HttpRequestBuilder) {
        val path = builder.url.buildString().let { fullUrl ->
            val urlObj = Url(fullUrl)
            urlObj.encodedPath.ifEmpty { "/" }
        }
        cookieHeaderProvider.buildCookieHeader(domain, path, isSecureTransport)?.let { cookieHeader ->
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

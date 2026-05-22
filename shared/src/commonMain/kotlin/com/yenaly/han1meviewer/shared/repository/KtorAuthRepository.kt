package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.LoginResult
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.network.setCookieHeaders
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.CookieHeaderProvider
import com.yenaly.han1meviewer.shared.session.SessionStore
import com.yenaly.han1meviewer.shared.session.SetCookieParser
import io.ktor.client.HttpClient
import io.ktor.client.request.forms.FormDataContent
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.Parameters
import io.ktor.http.Url

class KtorAuthRepository(
    private val sessionStore: SessionStore,
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : AuthRepository {
    private val cookieHeaderProvider = CookieHeaderProvider(sessionStore)
    private val baseDomain = Url(baseUrl).host

    override suspend fun login(email: String, password: String): LoginResult {
        val loginPage = client.get("$baseUrl/login") {
            applyCommonHeaders()
            applyStoredCookies()
        }
        saveResponseCookies(loginPage)

        val token = parser.parseLoginCsrf(loginPage.bodyAsText())
            ?: return LoginResult(isLoggedIn = false, userId = null, username = null)

        val loginResponse = client.post("$baseUrl/login") {
            applyCommonHeaders()
            applyStoredCookies()
            header("X-CSRF-TOKEN", token)
            setBody(
                FormDataContent(
                    Parameters.build {
                        append("_token", token)
                        append("email", email)
                        append("password", password)
                    }
                )
            )
        }
        saveResponseCookies(loginResponse)

        if (loginResponse.status.value !in 200..399) {
            return LoginResult(isLoggedIn = false, userId = null, username = null)
        }

        val loginPageAgain = client.get("$baseUrl/login") {
            applyCommonHeaders()
            applyStoredCookies()
        }
        saveResponseCookies(loginPageAgain)

        val isLoggedIn = loginPageAgain.status == HttpStatusCode.NotFound
        return LoginResult(
            isLoggedIn = isLoggedIn,
            userId = null,
            username = null,
        )
    }

    private suspend fun io.ktor.client.request.HttpRequestBuilder.applyStoredCookies() {
        cookieHeaderProvider.buildCookieHeader(baseDomain)?.let { cookieHeader ->
            header(HttpHeaders.Cookie, cookieHeader)
        }
    }

    private fun io.ktor.client.request.HttpRequestBuilder.applyCommonHeaders() {
        header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
        header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
    }

    private suspend fun saveResponseCookies(response: HttpResponse) {
        val cookies = SetCookieParser.parseAll(response.headers.setCookieHeaders(), fallbackDomain = baseDomain)
        cookieHeaderProvider.saveResponseCookies(cookies)
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

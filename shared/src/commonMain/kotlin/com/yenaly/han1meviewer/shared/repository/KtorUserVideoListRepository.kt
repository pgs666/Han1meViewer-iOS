package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.UserVideoListPage
import com.yenaly.han1meviewer.shared.model.UserVideoListType
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker.hasConfirmedLogin
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.serialization.json.Json
import io.ktor.client.HttpClient
import io.ktor.client.request.forms.submitForm
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import io.ktor.http.parameters

class KtorUserVideoListRepository(
    private val sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    client: HttpClient? = null,
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
    private val videoLanguageProvider: () -> String = { "zht" },
) : UserVideoListRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl, videoLanguageProvider)
    private val client: HttpClient = client ?: createHan1meHttpClient(saveCookies = cookieBridge::saveResponseCookies, isAlreadyLogin = { sessionStore.loadCookies().hasConfirmedLogin() })

    override suspend fun getUserVideoList(
        userId: String,
        type: UserVideoListType,
        page: Int,
    ): UserVideoListPage {
        val response = client.get("$baseUrl/user/$userId/${type.path}") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        val body = response.bodyAsText()
        return withContext(Dispatchers.Default) { parser.parseUserVideoList(body, page) }
    }

    override suspend fun getPlaylistVideos(listCode: String, page: Int): UserVideoListPage {
        val response = client.get("$baseUrl/playlist") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("list", listCode)
            parameter("page", page)
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        val body = response.bodyAsText()
        return withContext(Dispatchers.Default) { parser.parseUserVideoList(body, page) }
    }

    override suspend fun removeUserVideoListItem(
        userId: String,
        type: UserVideoListType,
        videoCode: String,
        csrfToken: String?,
    ) {
        val token = requireMutationCsrfToken(csrfToken)

        suspend fun submit(csrf: String): io.ktor.client.statement.HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.submitForm(
                url = "$baseUrl/deletePlayitem",
                formParameters = parameters {
                    append("playlist_id", type.path) // "likes" or "saves"
                    append("video_id", videoCode)
                    append("count", "1")
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
        requireSuccessfulMutation(response, "Failed to remove user list item.")
        val body = response.bodyAsText()
        val returnedVideoCode = try {
            val jsonObj = Json.decodeFromString<kotlinx.serialization.json.JsonObject>(body)
            jsonObj["video_id"]?.toString()?.trim('"')
        } catch (_: Exception) { null }
        if (returnedVideoCode != videoCode) {
            throw com.yenaly.han1meviewer.shared.model.DomainException(
                com.yenaly.han1meviewer.shared.model.DomainError.Unknown(
                    "Delete response video_id mismatch: expected $videoCode, got $returnedVideoCode"
                )
            )
        }
    }

    override suspend fun addToMyList(
        listCode: String,
        videoCode: String,
        isChecked: Boolean,
        csrfToken: String?,
    ) {
        val token = requireMutationCsrfToken(csrfToken)

        suspend fun submit(csrf: String): io.ktor.client.statement.HttpResponse {
            val cookieHeader = cookieBridge.storedCookieHeader()
            return client.submitForm(
                url = "$baseUrl/save",
                formParameters = parameters {
                    append("_token", csrf)
                    append("input_id", listCode)
                    append("video_id", videoCode)
                    append("is_checked", isChecked.toString())
                    append("user_id", "")
                },
            ) {
                header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
                header("X-CSRF-TOKEN", csrf)
                cookieHeader?.let { header(HttpHeaders.Cookie, it) }
            }
        }

        val response = submitMutationWithCsrfRetry(
            initialToken = token,
            refreshToken = { fetchFreshCsrfTokenAt(client, cookieBridge, parser, "$baseUrl/watch?v=$videoCode") },
            submit = ::submit,
        )
        cookieBridge.saveResponseCookies(response)
        requireSuccessfulMutation(response, "Failed to update list state.")
    }
}

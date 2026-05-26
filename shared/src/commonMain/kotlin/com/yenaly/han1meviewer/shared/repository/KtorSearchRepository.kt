package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HanimeInfo
import com.yenaly.han1meviewer.shared.model.PageResult
import com.yenaly.han1meviewer.shared.model.SearchParams
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

class KtorSearchRepository(
    private val sessionStore: SessionStore,
    private val baseUrl: String = HanimeNetworkDefaults.DEFAULT_BASE_URL,
    client: HttpClient? = null,
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : SearchRepository {
    private val cookieBridge = KtorCookieBridge(sessionStore, baseUrl)
    private val client: HttpClient = client ?: createHan1meHttpClient(cookieBridge::saveResponseCookies)

    override suspend fun search(params: SearchParams, page: Int): PageResult<HanimeInfo> {
        val response = client.get("$baseUrl/search") {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            parameter("page", page)
            params.keyword.takeIf { it.isNotBlank() }?.let { keyword -> parameter("query", keyword) }
            params.genre?.let { genre -> parameter("genre", genre) }
            params.sort?.let { sort -> parameter("sort", sort) }
            if (params.broad) parameter("broad", "on")
            params.releaseDate?.let { releaseDate -> parameter("date", releaseDate) }
            params.duration?.let { duration -> parameter("duration", duration) }
            params.tags.forEach { tag -> parameter("tags[]", tag) }
            params.brands.forEach { brand -> parameter("brands[]", brand) }
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)

        return parser.parseSearch(response.bodyAsText(), params, page)
    }
}

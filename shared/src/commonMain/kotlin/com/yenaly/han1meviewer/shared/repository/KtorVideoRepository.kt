package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders

class KtorVideoRepository(
    private val baseUrl: String = DEFAULT_BASE_URL,
    private val client: HttpClient = createHan1meHttpClient(),
    private val parser: KsoupHtmlParser = KsoupHtmlParser(),
) : VideoRepository {
    override suspend fun getVideo(videoCode: String): HanimeVideo {
        val html = client.get("$baseUrl/watch?v=$videoCode") {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        }.bodyAsText()

        return parser.parseVideo(html, videoCode)
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

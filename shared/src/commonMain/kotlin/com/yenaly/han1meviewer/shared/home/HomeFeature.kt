package com.yenaly.han1meviewer.shared.home

import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import kotlinx.serialization.Serializable

class HomeFeature {
    private val client: HttpClient = createHan1meHttpClient()
    private val parser = KsoupHtmlParser()

    suspend fun loadHome(): HomeFeedSnapshot {
        val html = client.get(DEFAULT_BASE_URL) {
            header(HttpHeaders.UserAgent, DEFAULT_USER_AGENT)
        }.bodyAsText()
        val homePage = parser.parseHome(html)
        val allItems = homePage.sections.flatMap { section -> section.items }
        val firstItem = allItems.firstOrNull()

        return HomeFeedSnapshot(
            summary = "Sections: ${homePage.sections.size}, items: ${allItems.size}",
            baseUrl = DEFAULT_BASE_URL,
            username = homePage.username,
            bannerTitle = homePage.banner?.title,
            firstVideoTitle = firstItem?.title,
            firstVideoCode = firstItem?.videoCode,
            sectionCount = homePage.sections.size,
            itemCount = allItems.size,
        )
    }

    private companion object {
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
                "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

@Serializable
data class HomeFeedSnapshot(
    val summary: String,
    val baseUrl: String,
    val username: String?,
    val bannerTitle: String?,
    val firstVideoTitle: String?,
    val firstVideoCode: String?,
    val sectionCount: Int,
    val itemCount: Int,
)

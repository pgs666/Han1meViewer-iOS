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
        val videos = homePage.sections.flatMap { section ->
            section.items.mapNotNull { item ->
                val videoCode = item.videoCode ?: return@mapNotNull null
                HomeVideoSnapshot(
                    videoCode = videoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
                    sectionTitle = section.title,
                    detailUrl = item.detailUrl,
                )
            }
        }
        val firstItem = videos.firstOrNull()

        return HomeFeedSnapshot(
            summary = "Sections: ${homePage.sections.size}, items: ${videos.size}",
            baseUrl = DEFAULT_BASE_URL,
            username = homePage.username,
            bannerTitle = homePage.banner?.title,
            firstVideoTitle = firstItem?.title,
            firstVideoCode = firstItem?.videoCode,
            sectionCount = homePage.sections.size,
            itemCount = videos.size,
            videos = videos.take(MAX_HOME_VIDEOS),
        )
    }

    private companion object {
        const val MAX_HOME_VIDEOS = 30
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
    private val videos: List<HomeVideoSnapshot>,
) {
    fun videoCount(): Int = videos.size

    fun videoAt(index: Int): HomeVideoSnapshot? = videos.getOrNull(index)
}

@Serializable
data class HomeVideoSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val sectionTitle: String,
    val detailUrl: String?,
)

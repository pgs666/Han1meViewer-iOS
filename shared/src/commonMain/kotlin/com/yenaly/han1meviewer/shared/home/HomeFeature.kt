package com.yenaly.han1meviewer.shared.home

import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.repository.KtorHomeRepository
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.serialization.Serializable

class HomeFeature(
    private val repository: HomeRepository,
) {
    constructor(sessionStore: SessionStore) : this(KtorHomeRepository(sessionStore))

    suspend fun loadHome(): HomeFeedSnapshot {
        val homePage = repository.getHomePage()
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

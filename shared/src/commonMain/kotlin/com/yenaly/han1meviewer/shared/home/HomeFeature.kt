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
        val sections = homePage.sections.mapNotNull { section ->
            val videos = section.items.mapNotNull { item ->
                val videoCode = item.videoCode ?: return@mapNotNull null
                HomeVideoSnapshot(
                    videoCode = videoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
                    sectionTitle = section.displayTitle(),
                    detailUrl = item.detailUrl,
                )
            }
            if (videos.isEmpty()) {
                null
            } else {
                HomeSectionSnapshot(
                    key = section.key,
                    title = section.displayTitle(),
                    videos = videos.take(MAX_SECTION_VIDEOS),
                )
            }
        }
        val videos = sections.flatMap { section -> section.allVideos() }
        val firstItem = videos.firstOrNull()

        return HomeFeedSnapshot(
            summary = "Sections: ${sections.size}, items: ${videos.size}",
            baseUrl = DEFAULT_BASE_URL,
            username = homePage.username,
            bannerTitle = homePage.banner?.title,
            firstVideoTitle = firstItem?.title,
            firstVideoCode = firstItem?.videoCode,
            sectionCount = sections.size,
            itemCount = videos.size,
            videos = videos.take(MAX_HOME_VIDEOS),
            sections = sections,
        )
    }

    private fun com.yenaly.han1meviewer.shared.model.HomeSection.displayTitle(): String {
        return HOME_SECTION_TITLES[key] ?: title
    }

    private companion object {
        const val MAX_HOME_VIDEOS = 30
        const val MAX_SECTION_VIDEOS = 12
        const val DEFAULT_BASE_URL = "https://hanime1.me"
        val HOME_SECTION_TITLES = mapOf(
            "latestRelease" to "最新上市",
            "latestHanime" to "最新上传",
            "ecchiAnime" to "里番",
            "shortEpisodeAnime" to "泡面番",
            "motionAnime" to "Motion Anime",
            "threeDCG" to "3D CG",
            "twoPointFiveDAnime" to "2.5D",
            "twoDAnime" to "2D",
            "aiGenerated" to "AI 生成",
            "mmd" to "MMD",
            "cosplay" to "Cosplay",
            "watchingNow" to "他们在看",
        )
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
    private val sections: List<HomeSectionSnapshot>,
) {
    fun videoCount(): Int = videos.size

    fun videoAt(index: Int): HomeVideoSnapshot? = videos.getOrNull(index)

    fun homeSectionCount(): Int = sections.size

    fun homeSectionAt(index: Int): HomeSectionSnapshot? = sections.getOrNull(index)
}

@Serializable
data class HomeSectionSnapshot(
    val key: String,
    val title: String,
    private val videos: List<HomeVideoSnapshot>,
) {
    fun videoCount(): Int = videos.size

    fun videoAt(index: Int): HomeVideoSnapshot? = videos.getOrNull(index)

    fun allVideos(): List<HomeVideoSnapshot> = videos
}

@Serializable
data class HomeVideoSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val sectionTitle: String,
    val detailUrl: String?,
)

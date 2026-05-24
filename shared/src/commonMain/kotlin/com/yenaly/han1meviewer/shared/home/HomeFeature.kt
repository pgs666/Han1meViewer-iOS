package com.yenaly.han1meviewer.shared.home

import com.yenaly.han1meviewer.shared.repository.HomeRepository
import kotlinx.serialization.Serializable

class HomeFeature(
    private val repository: HomeRepository,
) {
    suspend fun loadHome(): HomeFeedSnapshot {
        val homePage = repository.getHomePage()
        val sections = homePage.sections.mapNotNull { section ->
            val videos = section.items.mapNotNull { item ->
                val videoCode = item.videoCode ?: return@mapNotNull null
                HomeVideoSnapshot(
                    videoCode = videoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
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
        return HomeFeedSnapshot(
            username = homePage.username,
            avatarUrl = homePage.avatarUrl,
            bannerTitle = homePage.banner?.title,
            sectionCount = sections.size,
            itemCount = sections.sumOf { section -> section.videoCount() },
            sections = sections,
        )
    }

    private fun com.yenaly.han1meviewer.shared.model.HomeSection.displayTitle(): String {
        return HOME_SECTION_TITLES[key] ?: title
    }

    private companion object {
        const val MAX_SECTION_VIDEOS = 12
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
    val username: String?,
    val avatarUrl: String?,
    val bannerTitle: String?,
    val sectionCount: Int,
    val itemCount: Int,
    private val sections: List<HomeSectionSnapshot>,
) {
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
}

@Serializable
data class HomeVideoSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
)

package com.yenaly.han1meviewer.shared.home

import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker.hasConfirmedLogin
import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.serialization.Serializable

class HomeFeature(
    private val repository: HomeRepository,
    private val sessionStore: SessionStore? = null,
    private val onSessionCleared: () -> Unit = {},
) {
    @Throws(Exception::class)
    suspend fun loadHome(): HomeFeedSnapshot {
        val homePage = repository.getHomePage()
        if (sessionStore?.loadCookies()?.hasConfirmedLogin() == true &&
            homePage.userId.isNullOrBlank() &&
            homePage.username.isNullOrBlank()
        ) {
            sessionStore.clearLoginCookies()
            onSessionCleared()
            throw DomainException(DomainError.Auth("Login session expired. Please sign in again."))
        }
        val sections = homePage.sections.mapNotNull { section ->
            val videos = section.items.map { item ->
                HomeVideoSnapshot(
                    videoCode = item.videoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
                    duration = item.duration,
                    views = item.views,
                    uploadTime = item.uploadTime,
                    artist = item.currentArtist,
                    reviews = item.reviews,
                )
            }
            if (videos.isEmpty()) {
                null
            } else {
                HomeSectionSnapshot(
                    key = section.key,
                    title = section.key,
                    videos = videos.take(MAX_SECTION_VIDEOS),
                )
            }
        }
        return HomeFeedSnapshot(
            username = homePage.username,
            avatarUrl = homePage.avatarUrl,
            bannerTitle = homePage.banner?.title,
            bannerDescription = homePage.banner?.description,
            bannerImageUrl = homePage.banner?.imageUrl,
            bannerVideoCode = homePage.banner?.videoCode,
            sectionCount = sections.size,
            itemCount = sections.sumOf { section -> section.videoCount() },
            capturedAtEpochMillis = homePage.capturedAtEpochMillis,
            sections = sections,
        )
    }

    private companion object {
        const val MAX_SECTION_VIDEOS = 12
    }
}

@Serializable
data class HomeFeedSnapshot(
    val username: String?,
    val avatarUrl: String?,
    val bannerTitle: String?,
    val bannerDescription: String?,
    val bannerImageUrl: String?,
    val bannerVideoCode: String?,
    val sectionCount: Int,
    val itemCount: Int,
    val capturedAtEpochMillis: Long = 0L,
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
    val duration: String?,
    val views: String?,
    val uploadTime: String?,
    val artist: String?,
    val reviews: String?,
)

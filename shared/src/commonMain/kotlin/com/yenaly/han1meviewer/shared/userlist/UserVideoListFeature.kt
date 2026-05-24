package com.yenaly.han1meviewer.shared.userlist

import com.yenaly.han1meviewer.shared.model.UserVideoListType
import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.repository.UserVideoListRepository
import kotlinx.serialization.Serializable

class UserVideoListFeature(
    private val type: UserVideoListType,
    private val homeRepository: HomeRepository,
    private val listRepository: UserVideoListRepository,
) {
    suspend fun load(page: Int): UserVideoListSnapshot {
        val userId = homeRepository.getHomePage().userId
            ?: error("Login is required before loading this list.")
        val listPage = listRepository.getUserVideoList(userId, type, page)
        return UserVideoListSnapshot(
            page = listPage.page,
            hasNext = listPage.hasNext,
            description = listPage.description,
            videos = listPage.items.mapNotNull { item ->
                val videoCode = item.videoCode ?: return@mapNotNull null
                UserVideoListItemSnapshot(
                    videoCode = videoCode,
                    title = item.title,
                    coverUrl = item.coverUrl,
                    duration = item.duration,
                    views = item.views,
                    artist = item.currentArtist,
                    uploadTime = item.uploadTime,
                )
            },
        )
    }
}

@Serializable
data class UserVideoListSnapshot(
    val page: Int,
    val hasNext: Boolean,
    val description: String?,
    private val videos: List<UserVideoListItemSnapshot>,
) {
    fun videoCount(): Int = videos.size

    fun videoAt(index: Int): UserVideoListItemSnapshot? = videos.getOrNull(index)
}

@Serializable
data class UserVideoListItemSnapshot(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val duration: String?,
    val views: String?,
    val artist: String?,
    val uploadTime: String?,
)

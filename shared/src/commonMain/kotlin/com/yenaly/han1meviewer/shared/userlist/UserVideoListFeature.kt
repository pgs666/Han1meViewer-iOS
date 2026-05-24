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
    private var currentUserId: String? = null
    private var csrfToken: String? = null

    suspend fun load(page: Int): UserVideoListSnapshot {
        val userId = homeRepository.getHomePage().userId
            ?: error("Login is required before loading this list.")
        currentUserId = userId
        val listPage = listRepository.getUserVideoList(userId, type, page)
        csrfToken = listPage.csrfToken ?: csrfToken
        return listPage.toSnapshot()
    }

    suspend fun remove(videoCode: String): UserVideoListMutationSnapshot {
        val userId = currentUserId
            ?: homeRepository.getHomePage().userId
            ?: error("Login is required before modifying this list.")
        listRepository.removeUserVideoListItem(
            userId = userId,
            type = type,
            videoCode = videoCode,
            csrfToken = csrfToken,
        )
        return UserVideoListMutationSnapshot(videoCode = videoCode)
    }

    private fun com.yenaly.han1meviewer.shared.model.UserVideoListPage.toSnapshot(): UserVideoListSnapshot {
        return UserVideoListSnapshot(
            page = page,
            hasNext = hasNext,
            listDescription = listDescription,
            videos = items.mapNotNull { item ->
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

class PlaylistVideoListFeature(
    private val listCode: String,
    private val listRepository: UserVideoListRepository,
) {
    suspend fun load(page: Int): UserVideoListSnapshot {
        val listPage = listRepository.getPlaylistVideos(listCode, page)
        return listPage.toSnapshot()
    }

    private fun com.yenaly.han1meviewer.shared.model.UserVideoListPage.toSnapshot(): UserVideoListSnapshot {
        return UserVideoListSnapshot(
            page = page,
            hasNext = hasNext,
            listDescription = listDescription,
            videos = items.mapNotNull { item ->
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
    val listDescription: String?,
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

@Serializable
data class UserVideoListMutationSnapshot(
    val videoCode: String,
)

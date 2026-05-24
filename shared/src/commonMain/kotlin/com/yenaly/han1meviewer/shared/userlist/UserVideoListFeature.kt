package com.yenaly.han1meviewer.shared.userlist

import com.yenaly.han1meviewer.shared.model.UserVideoListType
import com.yenaly.han1meviewer.shared.repository.UserVideoListRepository
import kotlinx.serialization.Serializable

class UserVideoListFeature(
    private val type: UserVideoListType,
    private val currentUserIdProvider: suspend () -> String?,
    private val listRepository: UserVideoListRepository,
) {
    private var csrfToken: String? = null

    @Throws(Exception::class)
    suspend fun load(page: Int): UserVideoListSnapshot {
        val userId = resolveCurrentUserId()
            ?: return UserVideoListSnapshot.authRequired(page)
        val listPage = listRepository.getUserVideoList(userId, type, page)
        csrfToken = listPage.csrfToken ?: csrfToken
        return listPage.toSnapshot()
    }

    @Throws(Exception::class)
    suspend fun remove(videoCode: String): UserVideoListMutationSnapshot {
        val userId = resolveCurrentUserId()
            ?: return UserVideoListMutationSnapshot(videoCode = videoCode, authRequired = true)
        listRepository.removeUserVideoListItem(
            userId = userId,
            type = type,
            videoCode = videoCode,
            csrfToken = csrfToken,
        )
        return UserVideoListMutationSnapshot(videoCode = videoCode)
    }

    private suspend fun resolveCurrentUserId(): String? {
        return currentUserIdProvider()
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
    @Throws(Exception::class)
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
    val authRequired: Boolean = false,
    private val videos: List<UserVideoListItemSnapshot>,
) {
    fun videoCount(): Int = videos.size

    fun videoAt(index: Int): UserVideoListItemSnapshot? = videos.getOrNull(index)

    companion object {
        fun authRequired(page: Int): UserVideoListSnapshot {
            return UserVideoListSnapshot(
                page = page,
                hasNext = false,
                listDescription = null,
                authRequired = true,
                videos = emptyList(),
            )
        }
    }
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
    val authRequired: Boolean = false,
)

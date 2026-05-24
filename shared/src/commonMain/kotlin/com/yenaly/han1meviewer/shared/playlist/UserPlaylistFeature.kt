package com.yenaly.han1meviewer.shared.playlist

import com.yenaly.han1meviewer.shared.repository.HomeRepository
import com.yenaly.han1meviewer.shared.repository.UserPlaylistRepository
import kotlinx.serialization.Serializable

class UserPlaylistFeature(
    private val homeRepository: HomeRepository,
    private val playlistRepository: UserPlaylistRepository,
) {
    suspend fun load(page: Int): UserPlaylistSnapshot {
        val userId = homeRepository.getHomePage().userId
            ?: error("Login is required before loading playlists.")
        val pageData = playlistRepository.getPlaylists(userId, page)

        return UserPlaylistSnapshot(
            page = pageData.page,
            hasNext = pageData.hasNext,
            playlists = pageData.playlists.map { playlist ->
                UserPlaylistItemSnapshot(
                    listCode = playlist.listCode,
                    title = playlist.title,
                    total = playlist.total,
                    coverUrl = playlist.coverUrl,
                )
            },
        )
    }
}

@Serializable
data class UserPlaylistSnapshot(
    val page: Int,
    val hasNext: Boolean,
    private val playlists: List<UserPlaylistItemSnapshot>,
) {
    fun playlistCount(): Int = playlists.size

    fun playlistAt(index: Int): UserPlaylistItemSnapshot? = playlists.getOrNull(index)
}

@Serializable
data class UserPlaylistItemSnapshot(
    val listCode: String,
    val title: String,
    val total: Int,
    val coverUrl: String?,
)

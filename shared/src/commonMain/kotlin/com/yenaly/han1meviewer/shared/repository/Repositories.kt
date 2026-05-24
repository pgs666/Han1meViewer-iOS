package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.HanimeInfo
import com.yenaly.han1meviewer.shared.model.HanimeVideo
import com.yenaly.han1meviewer.shared.model.HomePage
import com.yenaly.han1meviewer.shared.model.MySubscriptions
import com.yenaly.han1meviewer.shared.model.OnlineWatchHistorySort
import com.yenaly.han1meviewer.shared.model.PageResult
import com.yenaly.han1meviewer.shared.model.SearchParams
import com.yenaly.han1meviewer.shared.model.UserPlaylistPage
import com.yenaly.han1meviewer.shared.model.UserVideoListPage
import com.yenaly.han1meviewer.shared.model.UserVideoListType

interface HomeRepository {
    suspend fun getHomePage(): HomePage
}

interface SearchRepository {
    suspend fun search(params: SearchParams, page: Int): PageResult<HanimeInfo>
}

interface VideoRepository {
    suspend fun getVideo(videoCode: String): HanimeVideo

    suspend fun setFavorite(
        videoCode: String,
        userId: String?,
        csrfToken: String?,
        isFavorite: Boolean,
    )

    suspend fun setMyListItem(
        listCode: String,
        videoCode: String,
        csrfToken: String?,
        isSelected: Boolean,
    )
}

interface FollowingRepository {
    suspend fun getSubscriptions(page: Int): MySubscriptions
}

interface UserVideoListRepository {
    suspend fun getUserVideoList(userId: String, type: UserVideoListType, page: Int): UserVideoListPage

    suspend fun getPlaylistVideos(listCode: String, page: Int): UserVideoListPage

    suspend fun removeUserVideoListItem(
        userId: String,
        type: UserVideoListType,
        videoCode: String,
        csrfToken: String?,
    )
}

interface UserPlaylistRepository {
    suspend fun getPlaylists(userId: String, page: Int): UserPlaylistPage
}

interface OnlineWatchHistoryRepository {
    suspend fun getHistories(userId: String, sort: OnlineWatchHistorySort, page: Int): UserVideoListPage

    suspend fun removeHistoryItem(videoCode: String, csrfToken: String?)
}

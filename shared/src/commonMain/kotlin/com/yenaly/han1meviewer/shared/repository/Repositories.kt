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
import com.yenaly.han1meviewer.shared.model.CommentPlace
import com.yenaly.han1meviewer.shared.model.CommentTargetType
import com.yenaly.han1meviewer.shared.model.VideoComment
import com.yenaly.han1meviewer.shared.model.VideoComments

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

    suspend fun setArtistSubscription(
        userId: String,
        artistId: String,
        csrfToken: String?,
        isSubscribed: Boolean,
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

    suspend fun addToMyList(
        listCode: String,
        videoCode: String,
        isChecked: Boolean,
        csrfToken: String?,
    )
}

interface UserPlaylistRepository {
    suspend fun getPlaylists(userId: String, page: Int): UserPlaylistPage

    suspend fun createPlaylist(
        csrfToken: String?,
        videoCode: String,
        title: String,
        description: String,
    )

    suspend fun modifyPlaylist(
        listCode: String,
        title: String,
        description: String,
        delete: Boolean = false,
        csrfToken: String?,
    )
}

interface OnlineWatchHistoryRepository {
    suspend fun getHistories(userId: String, sort: OnlineWatchHistorySort, page: Int): UserVideoListPage

    suspend fun removeHistoryItem(videoCode: String, csrfToken: String?)
}

interface CommentRepository {
    suspend fun getComments(type: CommentTargetType, code: String): VideoComments

    suspend fun getCommentReplies(commentId: String): VideoComments

    suspend fun postComment(
        csrfToken: String?,
        currentUserId: String,
        targetId: String,
        type: CommentTargetType,
        text: String,
    )

    suspend fun postReply(
        csrfToken: String?,
        replyCommentId: String,
        text: String,
    )

    suspend fun likeComment(
        csrfToken: String?,
        place: CommentPlace,
        isPositive: Boolean,
        comment: VideoComment,
    )

    suspend fun reportComment(
        userId: String?,
        csrfToken: String?,
        redirectUrl: String,
        reportableId: String?,
        reportableType: String?,
        reason: String,
    )
}

package com.yenaly.han1meviewer.shared.app

import com.yenaly.han1meviewer.shared.auth.CloudflareFeature
import com.yenaly.han1meviewer.shared.auth.WebLoginFeature
import com.yenaly.han1meviewer.shared.comment.CommentFeature
import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import com.yenaly.han1meviewer.shared.following.FollowingFeature
import com.yenaly.han1meviewer.shared.history.WatchHistoryFeature
import com.yenaly.han1meviewer.shared.history.WatchHistoryStore
import com.yenaly.han1meviewer.shared.history.OnlineWatchHistoryFeature
import com.yenaly.han1meviewer.shared.home.HomeFeature
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.repository.KtorFollowingRepository
import com.yenaly.han1meviewer.shared.repository.KtorCommentRepository
import com.yenaly.han1meviewer.shared.repository.KtorHomeRepository
import com.yenaly.han1meviewer.shared.repository.KtorOnlineWatchHistoryRepository
import com.yenaly.han1meviewer.shared.repository.KtorSearchRepository
import com.yenaly.han1meviewer.shared.repository.KtorUserPlaylistRepository
import com.yenaly.han1meviewer.shared.repository.KtorUserVideoListRepository
import com.yenaly.han1meviewer.shared.repository.KtorVideoRepository
import com.yenaly.han1meviewer.shared.search.SearchFeature
import com.yenaly.han1meviewer.shared.search.SearchHistoryStore
import com.yenaly.han1meviewer.shared.session.SessionStore
import com.yenaly.han1meviewer.shared.session.SqlDelightSessionStore
import com.yenaly.han1meviewer.shared.model.UserVideoListType
import com.yenaly.han1meviewer.shared.playlist.UserPlaylistFeature
import com.yenaly.han1meviewer.shared.userlist.PlaylistVideoListFeature
import com.yenaly.han1meviewer.shared.userlist.UserVideoListFeature
import com.yenaly.han1meviewer.shared.video.VideoFeature

class SharedAppEnvironment(
    driverFactory: DatabaseDriverFactory,
) {
    private val database = createDatabase(driverFactory)
    private val sessionStore: SessionStore = SqlDelightSessionStore(database)
    private val watchHistoryStore = WatchHistoryStore(database)
    private val searchHistoryStore = SearchHistoryStore(database)
    private val httpClient = createHan1meHttpClient()
    private val homeRepository = KtorHomeRepository(sessionStore, client = httpClient)
    private val followingRepository = KtorFollowingRepository(sessionStore, client = httpClient)
    private val searchRepository = KtorSearchRepository(sessionStore, client = httpClient)
    private val videoRepository = KtorVideoRepository(sessionStore, client = httpClient)
    private val commentRepository = KtorCommentRepository(sessionStore, client = httpClient)
    private val userVideoListRepository = KtorUserVideoListRepository(sessionStore, client = httpClient)
    private val userPlaylistRepository = KtorUserPlaylistRepository(sessionStore, client = httpClient)
    private val onlineWatchHistoryRepository = KtorOnlineWatchHistoryRepository(sessionStore, client = httpClient)
    private var cachedCurrentUserId: String? = null

    fun webLoginFeature(): WebLoginFeature {
        return WebLoginFeature(sessionStore, homeRepository)
    }

    fun cloudflareFeature(): CloudflareFeature {
        return CloudflareFeature(sessionStore)
    }

    fun homeFeature(): HomeFeature {
        return HomeFeature(homeRepository)
    }

    fun followingFeature(): FollowingFeature {
        return FollowingFeature(followingRepository)
    }

    fun searchFeature(): SearchFeature {
        return SearchFeature(
            repository = searchRepository,
            historyStore = searchHistoryStore,
        )
    }

    fun videoFeature(): VideoFeature {
        return VideoFeature(
            repository = videoRepository,
            watchHistoryStore = watchHistoryStore,
        )
    }

    fun commentFeature(): CommentFeature {
        return CommentFeature(commentRepository)
    }

    fun watchHistoryFeature(): WatchHistoryFeature {
        return WatchHistoryFeature(watchHistoryStore)
    }

    fun onlineWatchHistoryFeature(): OnlineWatchHistoryFeature {
        return OnlineWatchHistoryFeature(
            currentUserIdProvider = ::resolveCurrentUserId,
            historyRepository = onlineWatchHistoryRepository,
        )
    }

    fun watchLaterFeature(): UserVideoListFeature {
        return UserVideoListFeature(
            type = UserVideoListType.WatchLater,
            currentUserIdProvider = ::resolveCurrentUserId,
            listRepository = userVideoListRepository,
        )
    }

    fun favoriteVideoFeature(): UserVideoListFeature {
        return UserVideoListFeature(
            type = UserVideoListType.Favorites,
            currentUserIdProvider = ::resolveCurrentUserId,
            listRepository = userVideoListRepository,
        )
    }

    fun userPlaylistFeature(): UserPlaylistFeature {
        return UserPlaylistFeature(
            currentUserIdProvider = ::resolveCurrentUserId,
            playlistRepository = userPlaylistRepository,
        )
    }

    fun playlistVideoListFeature(listCode: String): PlaylistVideoListFeature {
        return PlaylistVideoListFeature(
            listCode = listCode,
            listRepository = userVideoListRepository,
        )
    }

    fun clearCachedCurrentUserId() {
        cachedCurrentUserId = null
    }

    private suspend fun resolveCurrentUserId(): String? {
        cachedCurrentUserId?.let { return it }
        return homeRepository.getHomePage().userId?.also { userId ->
            cachedCurrentUserId = userId
        }
    }
}

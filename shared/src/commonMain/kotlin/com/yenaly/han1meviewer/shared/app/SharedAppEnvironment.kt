package com.yenaly.han1meviewer.shared.app

import com.yenaly.han1meviewer.shared.auth.CloudflareFeature
import com.yenaly.han1meviewer.shared.auth.WebLoginFeature
import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import com.yenaly.han1meviewer.shared.following.FollowingFeature
import com.yenaly.han1meviewer.shared.history.WatchHistoryFeature
import com.yenaly.han1meviewer.shared.history.WatchHistoryStore
import com.yenaly.han1meviewer.shared.history.OnlineWatchHistoryFeature
import com.yenaly.han1meviewer.shared.home.HomeFeature
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.repository.KtorFollowingRepository
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
    private val userVideoListRepository = KtorUserVideoListRepository(sessionStore, client = httpClient)
    private val userPlaylistRepository = KtorUserPlaylistRepository(sessionStore, client = httpClient)
    private val onlineWatchHistoryRepository = KtorOnlineWatchHistoryRepository(sessionStore, client = httpClient)

    fun webLoginFeature(): WebLoginFeature {
        return WebLoginFeature(sessionStore)
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

    fun watchHistoryFeature(): WatchHistoryFeature {
        return WatchHistoryFeature(watchHistoryStore)
    }

    fun onlineWatchHistoryFeature(): OnlineWatchHistoryFeature {
        return OnlineWatchHistoryFeature(
            homeRepository = homeRepository,
            historyRepository = onlineWatchHistoryRepository,
        )
    }

    fun watchLaterFeature(): UserVideoListFeature {
        return UserVideoListFeature(
            type = UserVideoListType.WatchLater,
            homeRepository = homeRepository,
            listRepository = userVideoListRepository,
        )
    }

    fun favoriteVideoFeature(): UserVideoListFeature {
        return UserVideoListFeature(
            type = UserVideoListType.Favorites,
            homeRepository = homeRepository,
            listRepository = userVideoListRepository,
        )
    }

    fun userPlaylistFeature(): UserPlaylistFeature {
        return UserPlaylistFeature(
            homeRepository = homeRepository,
            playlistRepository = userPlaylistRepository,
        )
    }

    fun playlistVideoListFeature(listCode: String): PlaylistVideoListFeature {
        return PlaylistVideoListFeature(
            listCode = listCode,
            listRepository = userVideoListRepository,
        )
    }
}

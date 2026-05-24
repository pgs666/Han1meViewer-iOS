package com.yenaly.han1meviewer.shared.app

import com.yenaly.han1meviewer.shared.auth.WebLoginFeature
import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import com.yenaly.han1meviewer.shared.following.FollowingFeature
import com.yenaly.han1meviewer.shared.history.WatchHistoryFeature
import com.yenaly.han1meviewer.shared.history.WatchHistoryStore
import com.yenaly.han1meviewer.shared.home.HomeFeature
import com.yenaly.han1meviewer.shared.repository.KtorFollowingRepository
import com.yenaly.han1meviewer.shared.repository.KtorHomeRepository
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
    private val homeRepository = KtorHomeRepository(sessionStore)
    private val userVideoListRepository = KtorUserVideoListRepository(sessionStore)
    private val userPlaylistRepository = KtorUserPlaylistRepository(sessionStore)

    fun webLoginFeature(): WebLoginFeature {
        return WebLoginFeature(sessionStore)
    }

    fun homeFeature(): HomeFeature {
        return HomeFeature(homeRepository)
    }

    fun followingFeature(): FollowingFeature {
        return FollowingFeature(KtorFollowingRepository(sessionStore))
    }

    fun searchFeature(): SearchFeature {
        return SearchFeature(
            repository = KtorSearchRepository(sessionStore),
            historyStore = searchHistoryStore,
        )
    }

    fun videoFeature(): VideoFeature {
        return VideoFeature(
            repository = KtorVideoRepository(sessionStore),
            watchHistoryStore = watchHistoryStore,
        )
    }

    fun watchHistoryFeature(): WatchHistoryFeature {
        return WatchHistoryFeature(watchHistoryStore)
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

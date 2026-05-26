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
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker
import com.yenaly.han1meviewer.shared.auth.LoginSessionMarker.hasConfirmedLogin
import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import com.yenaly.han1meviewer.shared.repository.HanimeNetworkDefaults
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
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
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.concurrent.atomics.AtomicReference
import kotlin.concurrent.atomics.ExperimentalAtomicApi

@OptIn(ExperimentalAtomicApi::class)
class SharedAppEnvironment(
    driverFactory: DatabaseDriverFactory,
    baseUrl: String = "https://hanime1.me",
) {
    private val database = createDatabase(driverFactory)
    private val sessionStore: SessionStore = SqlDelightSessionStore(database)
    private val watchHistoryStore = WatchHistoryStore(database)
    private val searchHistoryStore = SearchHistoryStore(database)
    private val sharedCookieBridge = KtorCookieBridge(sessionStore, baseUrl)
    private val httpClient = createHan1meHttpClient(
        saveCookies = sharedCookieBridge::saveResponseCookies,
        isAlreadyLogin = { sessionStore.loadCookies().hasConfirmedLogin() }
    )
    private val homeRepository = KtorHomeRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val followingRepository = KtorFollowingRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val searchRepository = KtorSearchRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val videoRepository = KtorVideoRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val commentRepository = KtorCommentRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val userVideoListRepository = KtorUserVideoListRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val userPlaylistRepository = KtorUserPlaylistRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val onlineWatchHistoryRepository = KtorOnlineWatchHistoryRepository(sessionStore, baseUrl = baseUrl, client = httpClient)
    private val cachedCurrentUserId = AtomicReference<CachedCurrentUserId?>(null)
    private val currentUserIdCacheToken = AtomicReference(Any())
    private val currentUserIdLock = Mutex()

    fun webLoginFeature(): WebLoginFeature {
        return WebLoginFeature(
            sessionStore = sessionStore,
            homeRepository = homeRepository,
            onSessionCleared = ::clearCachedCurrentUserId,
        )
    }

    fun cloudflareFeature(): CloudflareFeature {
        return CloudflareFeature(sessionStore)
    }

    fun homeFeature(): HomeFeature {
        return HomeFeature(
            repository = homeRepository,
            sessionStore = sessionStore,
            onSessionCleared = ::clearCachedCurrentUserId,
        )
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
        currentUserIdCacheToken.store(Any())
        cachedCurrentUserId.store(null)
    }

    private suspend fun resolveCurrentUserId(): String? {
        cachedCurrentUserId.load()?.let { cache ->
            if (cache.token === currentUserIdCacheToken.load()) {
                return cache.userId
            }
        }
        val token = currentUserIdCacheToken.load()
        return currentUserIdLock.withLock {
            cachedCurrentUserId.load()?.let { cache ->
                if (cache.token === currentUserIdCacheToken.load()) {
                    return@withLock cache.userId
                }
            }
            homeRepository.getHomePage().userId?.takeIf { token === currentUserIdCacheToken.load() }?.also { userId ->
                cachedCurrentUserId.store(CachedCurrentUserId(userId, token))
            }
        }
    }

    private data class CachedCurrentUserId(
        val userId: String,
        val token: Any,
    )
}

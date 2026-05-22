package com.yenaly.han1meviewer.shared.app

import com.yenaly.han1meviewer.shared.auth.AuthFeature
import com.yenaly.han1meviewer.shared.auth.WebLoginFeature
import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import com.yenaly.han1meviewer.shared.home.HomeFeature
import com.yenaly.han1meviewer.shared.repository.KtorAuthRepository
import com.yenaly.han1meviewer.shared.repository.KtorHomeRepository
import com.yenaly.han1meviewer.shared.repository.KtorVideoRepository
import com.yenaly.han1meviewer.shared.session.SessionStore
import com.yenaly.han1meviewer.shared.session.SqlDelightSessionStore
import com.yenaly.han1meviewer.shared.video.VideoFeature

class SharedAppEnvironment(
    driverFactory: DatabaseDriverFactory,
) {
    private val sessionStore: SessionStore = SqlDelightSessionStore(createDatabase(driverFactory))

    fun authFeature(): AuthFeature {
        return AuthFeature(KtorAuthRepository(sessionStore))
    }

    fun webLoginFeature(): WebLoginFeature {
        return WebLoginFeature(sessionStore)
    }

    fun homeFeature(): HomeFeature {
        return HomeFeature(KtorHomeRepository(sessionStore))
    }

    fun videoFeature(): VideoFeature {
        return VideoFeature(KtorVideoRepository(sessionStore))
    }
}

package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.db.Han1meDatabase
import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.util.currentEpochMillis

class SqlDelightSessionStore(
    private val database: Han1meDatabase,
) : SessionStore {
    override suspend fun loadCookies(): List<SessionCookie> {
        database.sessionCookieQueries.deleteExpired(currentEpochMillis())
        return database.sessionCookieQueries.selectAll(::mapCookie).executeAsList()
    }

    override suspend fun saveCookies(cookies: List<SessionCookie>) {
        database.transaction {
            cookies.forEach { cookie ->
                database.sessionCookieQueries.upsert(
                    name = cookie.name,
                    value_ = cookie.value,
                    domain = cookie.domain,
                    path = cookie.path,
                    expires_at_epoch_millis = cookie.expiresAtEpochMillis,
                    secure = if (cookie.secure) 1L else 0L,
                    http_only = if (cookie.httpOnly) 1L else 0L,
                )
            }
        }
    }

    override suspend fun clear() {
        database.sessionCookieQueries.deleteAll()
    }

    private fun mapCookie(
        name: String,
        value: String,
        domain: String,
        path: String,
        expiresAtEpochMillis: Long?,
        secure: Long,
        httpOnly: Long,
    ): SessionCookie {
        return SessionCookie(
            name = name,
            value = value,
            domain = domain,
            path = path,
            expiresAtEpochMillis = expiresAtEpochMillis,
            secure = secure != 0L,
            httpOnly = httpOnly != 0L,
        )
    }

}

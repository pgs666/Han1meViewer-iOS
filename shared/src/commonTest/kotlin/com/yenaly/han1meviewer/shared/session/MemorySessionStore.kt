package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie

class MemorySessionStore(
    initialCookies: List<SessionCookie> = emptyList(),
) : SessionStore {
    private val cookies = initialCookies.toMutableList()

    override suspend fun loadCookies(): List<SessionCookie> = cookies.toList()

    override suspend fun saveCookies(cookies: List<SessionCookie>) {
        this.cookies.removeAll { existing ->
            cookies.any { newCookie ->
                existing.name == newCookie.name &&
                    existing.domain == newCookie.domain &&
                    existing.path == newCookie.path
            }
        }
        this.cookies.addAll(cookies)
    }

    override suspend fun clear() {
        cookies.clear()
    }
}

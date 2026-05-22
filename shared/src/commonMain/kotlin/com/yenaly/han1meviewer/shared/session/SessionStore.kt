package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie

interface SessionStore {
    suspend fun loadCookies(): List<SessionCookie>
    suspend fun saveCookies(cookies: List<SessionCookie>)
    suspend fun clear()
}

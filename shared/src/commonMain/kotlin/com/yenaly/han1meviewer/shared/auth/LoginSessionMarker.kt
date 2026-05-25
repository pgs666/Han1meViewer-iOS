package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.model.SessionCookie

internal object LoginSessionMarker {
    private const val cookieName = "han1me_ios_web_login_confirmed"
    private const val appCookieDomain = "han1meviewer.local"

    fun cookie(): SessionCookie {
        return SessionCookie(
            name = cookieName,
            value = "true",
            domain = appCookieDomain,
            secure = true,
        )
    }

    fun List<SessionCookie>.hasConfirmedLogin(): Boolean {
        return any { cookie ->
            cookie.name == cookieName &&
                cookie.value == "true" &&
                cookie.domain == appCookieDomain
        }
    }
}

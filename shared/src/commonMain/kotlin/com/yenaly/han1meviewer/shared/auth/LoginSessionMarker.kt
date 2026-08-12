package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.model.SessionCookie

internal object LoginSessionMarker {
    private const val cookieName = "han1me_ios_web_login_confirmed"
    fun cookie(domain: String = "hanime1.me"): SessionCookie {
        return SessionCookie(
            name = cookieName,
            value = "true",
            domain = domain.normalized(),
            secure = true,
        )
    }

    fun List<SessionCookie>.hasConfirmedLogin(domain: String = "hanime1.me"): Boolean {
        val siteDomain = domain.normalized()
        return any { cookie ->
            cookie.name == cookieName &&
                cookie.value == "true" &&
                cookie.domain.normalized() == siteDomain
        }
    }

    private fun String.normalized(): String = trim().removePrefix(".").lowercase()
}

package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie

internal fun SessionCookie.matchesDomain(requestDomain: String): Boolean {
    val normalizedRequestDomain = requestDomain.normalizedCookieDomain()
    val normalizedCookieDomain = domain.normalizedCookieDomain()
    return normalizedCookieDomain.isNotEmpty() &&
        (normalizedRequestDomain == normalizedCookieDomain ||
            normalizedRequestDomain.endsWith(".$normalizedCookieDomain"))
}

private fun String.normalizedCookieDomain(): String = trim().removePrefix(".").lowercase()

package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.session.SessionStore
import kotlinx.serialization.Serializable

class CloudflareFeature(
    private val sessionStore: SessionStore,
) {
    @Throws(Exception::class)
    suspend fun importChallengeCookieHeader(cookieHeader: String, domain: String): CloudflareChallengeSnapshot {
        val cookies = parseCookieHeader(cookieHeader, domain)
        sessionStore.saveCookies(cookies)

        return CloudflareChallengeSnapshot(
            hasClearance = cookies.any { cookie -> cookie.name == CLOUDFLARE_CLEARANCE_COOKIE },
            importedCookieCount = cookies.size,
        )
    }

    private fun parseCookieHeader(cookieHeader: String, domain: String): List<SessionCookie> {
        return cookieHeader.split(";")
            .mapNotNull { rawCookie ->
                val parts = rawCookie.trim().split("=", limit = 2)
                val name = parts.getOrNull(0)?.trim().orEmpty()
                val value = parts.getOrNull(1)?.trim().orEmpty()
                if (name.isBlank() || value.isBlank()) {
                    null
                } else {
                    SessionCookie(
                        name = name,
                        value = value,
                        domain = domain,
                    )
                }
            }
    }

    private companion object {
        const val CLOUDFLARE_CLEARANCE_COOKIE = "cf_clearance"
    }
}

@Serializable
data class CloudflareChallengeSnapshot(
    val hasClearance: Boolean,
    val importedCookieCount: Int,
)

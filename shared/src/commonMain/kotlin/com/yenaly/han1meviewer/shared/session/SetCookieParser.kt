package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

object SetCookieParser {
    fun parseAll(headers: List<String>, fallbackDomain: String): List<SessionCookie> {
        return headers.mapNotNull { header -> parse(header, fallbackDomain) }
    }

    fun parse(header: String, fallbackDomain: String): SessionCookie? {
        val parts = header.split(";").map { it.trim() }.filter { it.isNotEmpty() }
        val nameValue = parts.firstOrNull() ?: return null
        val separator = nameValue.indexOf('=')
        if (separator <= 0) return null

        val attributes = parts.drop(1).associate { part ->
            val attrSeparator = part.indexOf('=')
            if (attrSeparator <= 0) {
                part.lowercase() to ""
            } else {
                part.substring(0, attrSeparator).lowercase() to part.substring(attrSeparator + 1)
            }
        }

        return SessionCookie(
            name = nameValue.substring(0, separator),
            value = nameValue.substring(separator + 1),
            domain = attributes["domain"] ?: fallbackDomain,
            path = attributes["path"] ?: "/",
            expiresAtEpochMillis = attributes["max-age"]?.toLongOrNull()?.let { seconds ->
                currentEpochMillis() + seconds * 1000L
            },
        )
    }

    @OptIn(ExperimentalTime::class)
    private fun currentEpochMillis(): Long = Clock.System.now().toEpochMilliseconds()
}

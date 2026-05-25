package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.util.currentEpochMillis
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.Month
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant

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
            expiresAtEpochMillis = expirationMillis(attributes),
            secure = attributes.containsKey("secure"),
            httpOnly = attributes.containsKey("httponly"),
        )
    }

    private fun expirationMillis(attributes: Map<String, String>): Long? {
        return attributes["max-age"]?.toLongOrNull()?.let { seconds ->
            currentEpochMillis() + seconds * 1000L
        } ?: attributes["expires"]?.let(::parseExpiresMillis)
    }

    private fun parseExpiresMillis(value: String): Long? {
        val parts = value.replace(",", "").split(Regex("\\s+")).filter { it.isNotBlank() }
        val offset = if (parts.firstOrNull()?.all { it.isLetter() } == true) 1 else 0
        val day = parts.getOrNull(offset)?.toIntOrNull() ?: return null
        val month = parts.getOrNull(offset + 1)?.toMonth() ?: return null
        val year = parts.getOrNull(offset + 2)?.toIntOrNull() ?: return null
        val timeParts = parts.getOrNull(offset + 3)?.split(":") ?: return null
        val hour = timeParts.getOrNull(0)?.toIntOrNull() ?: return null
        val minute = timeParts.getOrNull(1)?.toIntOrNull() ?: return null
        val second = timeParts.getOrNull(2)?.toIntOrNull() ?: return null
        return runCatching {
            LocalDateTime(year, month, day, hour, minute, second)
                .toInstant(TimeZone.UTC)
                .toEpochMilliseconds()
        }.getOrNull()
    }

    private fun String.toMonth(): Month? {
        return when (lowercase().take(3)) {
            "jan" -> Month.JANUARY
            "feb" -> Month.FEBRUARY
            "mar" -> Month.MARCH
            "apr" -> Month.APRIL
            "may" -> Month.MAY
            "jun" -> Month.JUNE
            "jul" -> Month.JULY
            "aug" -> Month.AUGUST
            "sep" -> Month.SEPTEMBER
            "oct" -> Month.OCTOBER
            "nov" -> Month.NOVEMBER
            "dec" -> Month.DECEMBER
            else -> null
        }
    }
}

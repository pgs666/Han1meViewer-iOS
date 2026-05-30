package com.yenaly.han1meviewer.shared.model

sealed interface DomainError {
    val message: String

    /**
     * Stable, machine-readable classification token. The Swift layer only
     * receives a bridged `NSError` (whose `localizedDescription` comes from
     * the Kotlin exception message), so [DomainException] embeds this code
     * as a `[code]` prefix on its message and Swift parses it — that way the
     * UI can branch on error kind by CODE, not by matching translatable
     * English message text (which would silently break if the text changes).
     */
    val code: String

    data class Network(override val message: String, val statusCode: Int? = null) : DomainError {
        override val code: String get() = statusCode?.let { "network:$it" } ?: "network"
    }
    data class Parse(override val message: String) : DomainError {
        override val code: String get() = "parse"
    }
    data class Auth(override val message: String) : DomainError {
        override val code: String get() = "auth"
    }
    data class CloudflareBlocked(override val message: String) : DomainError {
        override val code: String get() = "cloudflare"
    }
    data class Unknown(override val message: String) : DomainError {
        override val code: String get() = "unknown"
    }
}

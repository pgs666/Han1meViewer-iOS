package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable

@Serializable
sealed interface AppResult<out T> {
    @Serializable
    data class Success<out T>(val value: T) : AppResult<T>

    @Serializable
    data class Failure(val error: DomainErrorDto) : AppResult<Nothing>
}

@Serializable
data class DomainErrorDto(
    val type: String,
    val message: String,
    val statusCode: Int? = null,
)

fun DomainError.toDto(): DomainErrorDto = when (this) {
    is DomainError.Auth -> DomainErrorDto("auth", message)
    is DomainError.CloudflareBlocked -> DomainErrorDto("cloudflare_blocked", message)
    is DomainError.Network -> DomainErrorDto("network", message, statusCode)
    is DomainError.Parse -> DomainErrorDto("parse", message)
    is DomainError.Unknown -> DomainErrorDto("unknown", message)
}

@Serializable
data class PageResult<T>(
    val items: List<T>,
    val page: Int,
    val hasNext: Boolean,
)

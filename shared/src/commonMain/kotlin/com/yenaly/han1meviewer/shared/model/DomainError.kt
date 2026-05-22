package com.yenaly.han1meviewer.shared.model

sealed interface DomainError {
    val message: String

    data class Network(override val message: String, val statusCode: Int? = null) : DomainError
    data class Parse(override val message: String) : DomainError
    data class Auth(override val message: String) : DomainError
    data class CloudflareBlocked(override val message: String) : DomainError
    data class Unknown(override val message: String) : DomainError
}

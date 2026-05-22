package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class LoginResult(
    val isLoggedIn: Boolean,
    val userId: String?,
    val username: String?,
)

@Serializable
data class SessionCookie(
    val name: String,
    val value: String,
    val domain: String,
    val path: String = "/",
    val expiresAtEpochMillis: Long? = null,
)

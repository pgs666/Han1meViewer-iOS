package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.repository.AuthRepository
import kotlinx.serialization.Serializable

class AuthFeature(
    private val repository: AuthRepository,
) {
    suspend fun login(email: String, password: String): AuthSnapshot {
        val result = repository.login(email, password)
        return AuthSnapshot(
            isLoggedIn = result.isLoggedIn,
            message = if (result.isLoggedIn) {
                "Login succeeded"
            } else {
                "Login failed. Check your email, password, or Cloudflare state."
            },
            username = result.username,
        )
    }
}

@Serializable
data class AuthSnapshot(
    val isLoggedIn: Boolean,
    val message: String,
    val username: String?,
)

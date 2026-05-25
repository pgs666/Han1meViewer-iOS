package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException

internal fun requireMutationCsrfToken(csrfToken: String?): String {
    return csrfToken?.takeIf { it.isNotBlank() }
        ?: throw DomainException(DomainError.Auth("Login session expired. Please sign in again."))
}

internal fun requireMutationUserId(userId: String?): String {
    return userId?.takeIf { it.isNotBlank() }
        ?: throw DomainException(DomainError.Auth("Login is required for this action."))
}

internal fun throwMutationFailure(message: String): Nothing {
    throw DomainException(DomainError.Unknown(message))
}

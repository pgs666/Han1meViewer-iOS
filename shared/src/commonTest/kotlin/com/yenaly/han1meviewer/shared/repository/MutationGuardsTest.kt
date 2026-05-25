package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class MutationGuardsTest {
    @Test
    fun requireMutationCsrfTokenRejectsMissingToken() {
        val error = assertFailsWith<DomainException> {
            requireMutationCsrfToken(" ")
        }

        assertEquals(DomainError.Auth("Login session expired. Please sign in again."), error.error)
    }

    @Test
    fun requireMutationUserIdRejectsMissingUserId() {
        val error = assertFailsWith<DomainException> {
            requireMutationUserId(null)
        }

        assertEquals(DomainError.Auth("Login is required for this action."), error.error)
    }

    @Test
    fun throwMutationFailureUsesDomainException() {
        val error = assertFailsWith<DomainException> {
            throwMutationFailure("failed")
        }

        assertEquals(DomainError.Unknown("failed"), error.error)
    }
}

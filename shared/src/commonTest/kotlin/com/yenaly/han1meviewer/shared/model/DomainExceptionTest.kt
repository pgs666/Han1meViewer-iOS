package com.yenaly.han1meviewer.shared.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DomainExceptionTest {
    @Test
    fun messageCarriesStableCodePrefixForSwiftBridge() {
        // The Swift layer parses this leading [code] token (the bridged
        // NSError's localizedDescription is exactly this message), so the
        // format must stay "[code] message".
        assertEquals(
            "[cloudflare] blocked",
            DomainException(DomainError.CloudflareBlocked("blocked")).message,
        )
        assertEquals(
            "[network:403] denied",
            DomainException(DomainError.Network("denied", statusCode = 403)).message,
        )
        assertEquals("[network] oops", DomainException(DomainError.Network("oops")).message)
        assertEquals("[auth] expired", DomainException(DomainError.Auth("expired")).message)
        assertEquals("[unknown] failed", DomainException(DomainError.Unknown("failed")).message)
    }

    @Test
    fun codeAccessorMirrorsError() {
        assertEquals("cloudflare", DomainException(DomainError.CloudflareBlocked("x")).code)
        assertTrue(DomainException(DomainError.Network("x", 419)).code == "network:419")
    }
}

package com.yenaly.han1meviewer.shared.network

import com.yenaly.han1meviewer.shared.test.runTest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private const val CF_BODY = "<html><script>window._cf_chl_opt={}</script></html>"

class DomainFallbackTest {
    @Test
    fun readGetFallsBackToBackupDomainWhenPrimaryCloudflareBlocked() = runTest {
        val hostsTried = mutableListOf<String>()
        val engine = MockEngine { request ->
            hostsTried += request.url.host
            if (request.url.host == "hanime1.me") {
                respond(CF_BODY, HttpStatusCode.ServiceUnavailable, headersOf())
            } else {
                respond("ok-from-backup", HttpStatusCode.OK)
            }
        }
        val client = createHan1meHttpClient(engine = engine)

        val body = client.get("https://hanime1.me/").bodyAsText()

        assertEquals("ok-from-backup", body)
        assertEquals("hanime1.me", hostsTried.first())
        assertTrue(hostsTried.size >= 2, "expected a fallback attempt on a backup host")
        assertTrue(hostsTried.drop(1).all { it != "hanime1.me" }, "retries must target backup hosts")
    }

    @Test
    fun postMutationDoesNotRotateDomain() = runTest {
        val hostsTried = mutableListOf<String>()
        val engine = MockEngine { request ->
            hostsTried += request.url.host
            respond(CF_BODY, HttpStatusCode.ServiceUnavailable, headersOf())
        }
        val client = createHan1meHttpClient(engine = engine)

        runCatching { client.post("https://hanime1.me/like") }

        assertTrue(hostsTried.all { it == "hanime1.me" }, "POST must never rotate domains, got: $hostsTried")
    }
}

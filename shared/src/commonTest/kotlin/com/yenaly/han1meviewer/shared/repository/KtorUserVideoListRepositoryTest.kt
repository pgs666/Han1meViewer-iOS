package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.network.testHttpClient
import com.yenaly.han1meviewer.shared.session.MemorySessionStore
import com.yenaly.han1meviewer.shared.test.runTest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import kotlin.test.Test
import kotlin.test.assertTrue

class KtorUserVideoListRepositoryTest {
    @Test
    fun addToMyListSendsAndroidFormParameters() = runTest {
        var capturedBody = ""
        val engine = MockEngine { request ->
            capturedBody = (request.body as? OutgoingContent.ByteArrayContent)
                ?.bytes()
                ?.decodeToString()
                .orEmpty()
            respond("ok", HttpStatusCode.OK)
        }
        val repo = KtorUserVideoListRepository(
            sessionStore = MemorySessionStore(),
            client = testHttpClient(engine),
        )

        repo.addToMyList(listCode = "list-1", videoCode = "12345", isChecked = true, csrfToken = "tok")

        assertTrue("is_checked=true" in capturedBody, "expected is_checked=true, got: $capturedBody")
        assertTrue("user_id=" in capturedBody, "expected user_id field, got: $capturedBody")
    }
}

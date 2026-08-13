package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.network.testHttpClient
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.MemorySessionStore
import com.yenaly.han1meviewer.shared.test.runTest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import kotlin.test.Test
import kotlin.test.assertEquals

class KtorSearchRepositoryTest {
    @Test
    fun subscribedArtistUsesSubscriptionEndpointAndQuery() = runTest {
        var requestedPath = ""
        var requestedQuery: String? = null
        val html = """
            <html><body>
              <div class="subscriptions-nav"></div>
              <div class="content-padding-new">
                <div class="video-item-container" title="[Eros] Complete">
                  <a class="video-link" href="/watch?v=98758"></a>
                  <img class="main-thumb" src="/cover.jpg">
                  <div class="subtitle"><a>Eros • 4年前</a></div>
                </div>
              </div>
            </body></html>
        """.trimIndent()
        val engine = MockEngine { request ->
            requestedPath = request.url.encodedPath
            requestedQuery = request.url.parameters["query"]
            respond(html, HttpStatusCode.OK)
        }
        val repository = KtorSearchRepository(
            sessionStore = MemorySessionStore(),
            baseUrl = "https://mirror.example/custom",
            client = testHttpClient(engine),
            parser = KsoupHtmlParser("https://mirror.example/custom"),
        )

        val result = repository.searchSubscribedArtist("Eros", page = 1)

        assertEquals("/custom/subscriptions", requestedPath)
        assertEquals("Eros", requestedQuery)
        assertEquals("98758", result.items.single().videoCode)
    }
}

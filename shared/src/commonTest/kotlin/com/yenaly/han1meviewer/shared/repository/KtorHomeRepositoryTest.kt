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

class KtorHomeRepositoryTest {
    @Test
    fun requestsCustomHomepagePathExactly() = runTest {
        var requestedUrl = ""
        val html = """
            <html><body>
              <div id="home-rows-wrapper">
                <div><div class="horizontal-card">
                  <a href="/watch?v=123"></a>
                  <img src="/cover.jpg">
                  <div class="title">Mirror video</div>
                </div></div>
              </div>
            </body></html>
        """.trimIndent()
        val engine = MockEngine { request ->
            requestedUrl = request.url.toString()
            respond(html, HttpStatusCode.OK)
        }
        val homeUrl = "https://mirror.example/enter"
        val repository = KtorHomeRepository(
            sessionStore = MemorySessionStore(),
            baseUrl = homeUrl,
            client = testHttpClient(engine),
            parser = KsoupHtmlParser(homeUrl),
        )

        repository.getHomePage()

        assertEquals(homeUrl, requestedUrl)
    }
}

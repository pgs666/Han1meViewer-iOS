package com.yenaly.han1meviewer.shared

import com.yenaly.han1meviewer.shared.network.createHan1meHttpClient
import io.ktor.client.request.get
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.Serializable

class SharedSmokeTest {
    fun message(): String = "Han1meShared is linked"

    suspend fun fetchSomething(): SmokeFetchResult {
        val body = createHan1meHttpClient()
            .use { client -> client.get("https://example.com").bodyAsText() }

        return SmokeFetchResult(
            sourceUrl = "https://example.com",
            containsExampleDomain = body.contains("Example Domain"),
            bodyLength = body.length,
        )
    }
}

@Serializable
data class SmokeFetchResult(
    val sourceUrl: String,
    val containsExampleDomain: Boolean,
    val bodyLength: Int,
)

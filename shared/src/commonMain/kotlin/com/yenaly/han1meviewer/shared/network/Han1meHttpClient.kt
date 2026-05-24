package com.yenaly.han1meviewer.shared.network

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpResponseValidator
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

internal fun createHan1meHttpClient(): HttpClient = HttpClient {
    install(ContentNegotiation) {
        json(
            Json {
                ignoreUnknownKeys = true
                explicitNulls = false
            }
        )
    }
    install(HttpTimeout) {
        requestTimeoutMillis = 30_000
        connectTimeoutMillis = 15_000
        socketTimeoutMillis = 30_000
    }
    install(Logging) {
        level = LogLevel.INFO
    }
    HttpResponseValidator {
        validateResponse { response ->
            if (response.status == HttpStatusCode.Forbidden && response.headers.isCloudflareChallenge()) {
                throw DomainException(
                    DomainError.CloudflareBlocked(
                        "Cloudflare blocked this request. Open the site in the login browser and try again."
                    )
                )
            }
        }
    }
}

internal fun Headers.setCookieHeaders(): List<String> = getAll(HttpHeaders.SetCookie).orEmpty()

private fun Headers.isCloudflareChallenge(): Boolean {
    val mitigated = this["cf-mitigated"]?.equals("challenge", ignoreCase = true) == true
    val server = this[HttpHeaders.Server]?.contains("cloudflare", ignoreCase = true) == true
    val hasCloudflareHeader = names().any { name -> name.startsWith("cf-", ignoreCase = true) }
    return mitigated || server || hasCloudflareHeader
}

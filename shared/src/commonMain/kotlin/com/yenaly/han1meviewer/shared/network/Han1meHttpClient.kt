package com.yenaly.han1meviewer.shared.network

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpResponseValidator
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.statement.bodyAsText
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
        level = LogLevel.NONE
    }
    HttpResponseValidator {
        validateResponse { response ->
            if (response.isCloudflareChallenge()) {
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

private suspend fun io.ktor.client.statement.HttpResponse.isCloudflareChallenge(): Boolean {
    if (headers.hasCloudflareMitigationHeader()) {
        return status == HttpStatusCode.Forbidden || status == HttpStatusCode.ServiceUnavailable
    }
    if (status != HttpStatusCode.ServiceUnavailable) {
        return false
    }
    val text = runCatching { bodyAsText() }.getOrDefault("")
    return text.contains("cf-browser-verification", ignoreCase = true) ||
        text.contains("cf-challenge", ignoreCase = true) ||
        text.contains("cloudflare", ignoreCase = true)
}

private fun Headers.hasCloudflareMitigationHeader(): Boolean {
    val value = this["cf-mitigated"] ?: return false
    return value.equals("challenge", ignoreCase = true) ||
        value.equals("true", ignoreCase = true)
}

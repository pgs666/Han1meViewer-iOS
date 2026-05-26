package com.yenaly.han1meviewer.shared.network

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpRequestRetry
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
    install(HttpRequestRetry) {
        retryOnExceptionIf(maxRetries = 2) { _, cause ->
            cause !is DomainException
        }
        exponentialDelay()
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
            when (response.status) {
                HttpStatusCode.Unauthorized -> throw DomainException(
                    DomainError.Auth("Login session expired. Please sign in again.")
                )
                HttpStatusCode.Forbidden -> throw DomainException(
                    DomainError.Network("Access denied. This may be an IP or region block.", response.status.value)
                )
                HttpStatusCode.NotFound -> throw DomainException(
                    DomainError.Network("Requested content was not found.", response.status.value)
                )
                HttpStatusCode.TooManyRequests -> throw DomainException(
                    DomainError.Network("Too many requests. Please try again later.", response.status.value)
                )
                else -> {
                    if (response.status.value >= 500) {
                        throw DomainException(
                            DomainError.Network("Server error. Please try again later.", response.status.value)
                        )
                    }
                }
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
    return text.hasCloudflareChallengeBody()
}

internal fun String.hasCloudflareChallengeBody(): Boolean {
    return contains("cf-browser-verification", ignoreCase = true) ||
        contains("cf-challenge", ignoreCase = true) ||
        contains("challenge-platform", ignoreCase = true) ||
        contains("cf_chl_opt", ignoreCase = true) ||
        contains("/cdn-cgi/challenge-platform/", ignoreCase = true)
}

private fun Headers.hasCloudflareMitigationHeader(): Boolean {
    val value = this["cf-mitigated"] ?: return false
    return value.equals("challenge", ignoreCase = true) ||
        value.equals("true", ignoreCase = true)
}

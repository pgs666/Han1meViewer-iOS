package com.yenaly.han1meviewer.shared.network

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import com.yenaly.han1meviewer.shared.repository.HanimeNetworkDefaults
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.HttpClientConfig
import io.ktor.client.plugins.HttpRequestRetry
import io.ktor.http.HttpMethod
import io.ktor.client.plugins.HttpResponseValidator
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.statement.bodyAsText
import io.ktor.client.plugins.observer.ResponseObserver
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

internal fun createHan1meHttpClient(
    saveCookies: (suspend (io.ktor.client.statement.HttpResponse) -> Unit)? = null,
    isAlreadyLogin: (suspend () -> Boolean)? = null,
    engine: HttpClientEngine? = null,
): HttpClient {
    val config: HttpClientConfig<*>.() -> Unit = {
        install(ContentNegotiation) {
            json(
                Json {
                    ignoreUnknownKeys = true
                    explicitNulls = false
                }
            )
        }
        if (saveCookies != null) {
            install(ResponseObserver) {
                onResponse { response -> saveCookies(response) }
            }
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
            socketTimeoutMillis = 30_000
        }
        install(HttpRequestRetry) {
            // Read-only GET/HEAD requests fall back across the backup
            // domains (matching Android HANIME_URL) when the primary is
            // Cloudflare-blocked or unreachable. POST mutations are never
            // rotated cross-domain — CSRF token / session cookies are bound
            // to the domain the page was loaded from.
            retryOnExceptionIf(maxRetries = HanimeNetworkDefaults.BACKUP_HOSTNAMES.size - 1) { request, cause ->
                if (request.method !in setOf(HttpMethod.Get, HttpMethod.Head)) return@retryOnExceptionIf false
                when (cause) {
                    is DomainException -> cause.error is DomainError.CloudflareBlocked
                    else -> true // transient IO / connection failures
                }
            }
            modifyRequest { request ->
                val host = request.url.host
                if (host in HanimeNetworkDefaults.BACKUP_HOSTNAMES &&
                    request.method in setOf(HttpMethod.Get, HttpMethod.Head)
                ) {
                    HanimeNetworkDefaults.BACKUP_HOSTNAMES.getOrNull(retryCount)?.let { request.url.host = it }
                }
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
                HttpStatusCode.NotFound -> {
                    if (isAlreadyLogin?.invoke() == false) {
                        throw DomainException(DomainError.Auth("Not logged in. Please sign in first."))
                    }
                    throw DomainException(
                        DomainError.Network("Requested content was not found.", response.status.value)
                    )
                }
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
    return if (engine != null) HttpClient(engine, config) else HttpClient(config)
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

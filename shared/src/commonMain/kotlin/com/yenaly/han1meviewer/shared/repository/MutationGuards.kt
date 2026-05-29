package com.yenaly.han1meviewer.shared.repository

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import com.yenaly.han1meviewer.shared.parser.KsoupHtmlParser
import com.yenaly.han1meviewer.shared.session.KtorCookieBridge
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.isSuccess
import kotlinx.coroutines.CancellationException

/**
 * Fetches [pageUrl] solely to (a) refresh cookies (the server rotates
 * XSRF-TOKEN / laravel_session as part of its security model) and
 * (b) extract a fresh `_token` for retrying a mutation that just
 * returned 419. Returns null if the page fails to load — the caller then
 * surfaces the original 419. Shared by every repository's mutation retry.
 */
internal suspend fun fetchFreshCsrfTokenAt(
    client: HttpClient,
    cookieBridge: KtorCookieBridge,
    parser: KsoupHtmlParser,
    pageUrl: String,
): String? {
    return try {
        val response = client.get(pageUrl) {
            header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
            header(HttpHeaders.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            cookieBridge.applyStoredCookies(this)
        }
        cookieBridge.saveResponseCookies(response)
        if (response.status.value !in 200..299) return null
        parser.extractCsrfToken(response.bodyAsText())
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        null
    }
}

internal fun requireMutationCsrfToken(csrfToken: String?): String {
    return csrfToken?.takeIf { it.isNotBlank() }
        ?: throw DomainException(DomainError.Auth("Login session expired. Please sign in again."))
}

internal fun mutationCsrfTokenOrFallback(csrfToken: String?, fallback: String): String {
    return csrfToken?.takeIf { it.isNotBlank() } ?: fallback
}

internal fun requireMutationUserId(userId: String?): String {
    return userId?.takeIf { it.isNotBlank() }
        ?: throw DomainException(DomainError.Auth("Login is required for this action."))
}

internal fun throwMutationFailure(message: String): Nothing {
    throw DomainException(DomainError.Unknown(message))
}

internal fun requireSuccessfulMutationStatus(status: HttpStatusCode, message: String) {
    if (!status.isSuccess()) {
        throwMutationFailure("$message HTTP ${status.value}.")
    }
}

internal fun requireSuccessfulMutation(response: HttpResponse, message: String) {
    requireSuccessfulMutationStatus(response.status, message)
}

/**
 * Submits a mutation, transparently retrying once with a freshly-fetched
 * CSRF token if the first attempt comes back as HTTP 419 (Laravel's
 * "Page Expired" — server's session csrf has rotated since the page was
 * loaded). The caller provides a `submit` lambda that builds and sends
 * the request given a token, and a `refreshToken` lambda that returns a
 * fresh token by re-reading the page (also has the side-effect of
 * refreshing cookies on the way through).
 *
 * If `refreshToken` returns null (e.g. user got logged out), the original
 * 419 response is returned untouched and the caller's
 * `requireSuccessfulMutation` will surface the failure.
 */
internal const val HTTP_PAGE_EXPIRED = 419

internal suspend fun submitMutationWithCsrfRetry(
    initialToken: String,
    refreshToken: suspend () -> String?,
    submit: suspend (csrfToken: String) -> HttpResponse,
): HttpResponse {
    val initial = submit(initialToken)
    if (initial.status.value != HTTP_PAGE_EXPIRED) return initial
    val fresh = refreshToken() ?: return initial
    return submit(fresh)
}

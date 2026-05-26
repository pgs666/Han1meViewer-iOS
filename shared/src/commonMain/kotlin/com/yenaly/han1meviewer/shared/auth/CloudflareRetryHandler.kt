package com.yenaly.han1meviewer.shared.auth

import com.yenaly.han1meviewer.shared.model.DomainError
import com.yenaly.han1meviewer.shared.model.DomainException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.concurrent.atomics.AtomicReference
import kotlin.concurrent.atomics.ExperimentalAtomicApi

/**
 * Handles Cloudflare challenge resolution and automatic request retry.
 * 
 * When a CF challenge is detected:
 * 1. The HTTP client throws [DomainError.CloudflareBlocked]
 * 2. The ViewModel calls [retryAfterCloudflareResolution] which catches the exception
 * 3. [waitForResolution] suspends until the challenge is resolved
 * 4. The iOS layer shows the CF challenge UI and calls [signalResolved] when done
 * 5. The suspended coroutine resumes and the request is retried
 */
@OptIn(ExperimentalAtomicApi::class)
object CloudflareRetryHandler {
    private val currentChallenge = AtomicReference<CompletableDeferred<Unit>?>(null)
    private val mutex = Mutex()

    /**
     * Executes [block] and retries if a Cloudflare challenge is detected.
     * 
     * If [block] throws [DomainError.CloudflareBlocked], this function will:
     * 1. Create a deferred that the iOS layer can wait on
     * 2. Suspend until [signalResolved] or [signalFailed] is called
     * 3. Retry [block] after the challenge is resolved
     * 
     * @param onChallengeDetected Called when a CF challenge is detected. 
     *        The iOS layer should show the CF UI in this callback.
     * @param block The block to execute (typically a repository call)
     * @return The result of [block]
     * @throws DomainException if the challenge fails or [block] throws a non-CF exception
     */
    suspend fun <T> retryAfterCloudflareResolution(
        onChallengeDetected: suspend () -> Unit = {},
        maxRetries: Int = 1,
        block: suspend () -> T,
    ): T {
        var lastException: Exception? = null
        repeat(maxRetries + 1) { attempt ->
            try {
                return block()
            } catch (e: DomainException) {
                if (e.error is DomainError.CloudflareBlocked) {
                    lastException = e
                    if (attempt < maxRetries) {
                        // Show the CF UI
                        onChallengeDetected()
                        // Wait for resolution
                        waitForResolution()
                    }
                } else {
                    throw e
                }
            }
        }
        throw lastException ?: DomainException(
            DomainError.CloudflareBlocked("Cloudflare challenge failed after $maxRetries retries")
        )
    }

    /**
     * Waits for the current CF challenge to be resolved.
     * If no challenge is active, creates a new one and waits.
     * 
     * @return true when the challenge is resolved
     */
    suspend fun waitForResolution(): Boolean {
        val deferred = mutex.withLock {
            val existing = currentChallenge.load()
            if (existing != null) {
                return@withLock existing
            }
            val newDeferred = CompletableDeferred<Unit>()
            currentChallenge.store(newDeferred)
            newDeferred
        }
        
        deferred.await()
        return true
    }

    /**
     * Signals that the CF challenge has been resolved.
     * This resumes any coroutines waiting in [waitForResolution].
     */
    fun signalResolved() {
        val deferred = currentChallenge.exchange(null)
        deferred?.complete(Unit)
    }

    /**
     * Signals that the CF challenge has failed.
     * This resumes any coroutines waiting in [waitForResolution] with an exception.
     */
    fun signalFailed(reason: String) {
        val deferred = currentChallenge.exchange(null)
        deferred?.completeExceptionally(
            CloudflareChallengeFailedException(reason)
        )
    }

    /**
     * Checks if a CF challenge is currently active.
     */
    fun isChallengeActive(): Boolean {
        return currentChallenge.load() != null
    }
}

class CloudflareChallengeFailedException(reason: String) : Exception(reason)

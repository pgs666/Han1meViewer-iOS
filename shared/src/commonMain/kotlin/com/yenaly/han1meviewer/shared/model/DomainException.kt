package com.yenaly.han1meviewer.shared.model

class DomainException(
    val error: DomainError,
) : RuntimeException("[${error.code}] ${error.message}") {
    /** Convenience accessor mirroring [DomainError.code] for the bridge. */
    val code: String get() = error.code
}

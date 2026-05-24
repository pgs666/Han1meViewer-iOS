package com.yenaly.han1meviewer.shared.model

class DomainException(
    val error: DomainError,
) : RuntimeException(error.message)

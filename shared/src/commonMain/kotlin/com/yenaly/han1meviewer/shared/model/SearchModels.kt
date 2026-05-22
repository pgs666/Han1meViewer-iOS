package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class SearchParams(
    val keyword: String,
    val tags: List<String> = emptyList(),
    val brands: List<String> = emptyList(),
    val sort: String? = null,
    val duration: String? = null,
    val releaseDate: String? = null,
)

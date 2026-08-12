package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class HanimeInfo(
    val title: String,
    val videoCode: String,
    val coverUrl: String?,
    val detailUrl: String?,
    val duration: String? = null,
    val views: String? = null,
    val uploadTime: String? = null,
    val genre: String? = null,
    val reviews: String? = null,
    val currentArtist: String? = null,
    val watched: Boolean = false,
    val isPlaying: Boolean = false,
    val itemType: HanimeItemType = HanimeItemType.Normal,
)

@Serializable
enum class HanimeItemType {
    Normal,
    Simplified,
}

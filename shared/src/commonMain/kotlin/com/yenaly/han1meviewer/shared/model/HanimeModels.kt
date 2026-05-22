package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable
import kotlin.time.Clock
import kotlin.time.ExperimentalTime

@Serializable
data class HanimeInfo(
    val title: String,
    val videoCode: String?,
    val coverUrl: String?,
    val detailUrl: String?,
    val duration: String? = null,
    val watchedCount: String? = null,
)

@Serializable
data class HomePage(
    val csrfToken: String?,
    val avatarUrl: String?,
    val username: String?,
    val banner: HomeBanner?,
    val sections: List<HomeSection>,
    val userId: String?,
    val capturedAtEpochMillis: Long = currentEpochMillis(),
)

@OptIn(ExperimentalTime::class)
private fun currentEpochMillis(): Long = Clock.System.now().toEpochMilliseconds()

@Serializable
data class HomeBanner(
    val title: String,
    val description: String?,
    val imageUrl: String,
    val videoCode: String?,
)

@Serializable
data class HomeSection(
    val key: String,
    val title: String,
    val items: List<HanimeInfo>,
)

@Serializable
data class HanimeVideo(
    val videoCode: String,
    val title: String,
    val coverUrl: String?,
    val description: String?,
    val tags: List<String>,
    val brand: String?,
    val releaseDate: String?,
    val sources: List<PlaybackSource>,
)

@Serializable
data class PlaybackSource(
    val label: String,
    val url: String,
    val isDefault: Boolean = false,
)

package com.yenaly.han1meviewer.shared.model

import com.yenaly.han1meviewer.shared.util.currentEpochMillis
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

@Serializable
data class HomePage(
    val csrfToken: String?,
    val avatarUrl: String?,
    val username: String?,
    val banner: HomeBanner?,
    val sections: List<HomeSection>,
    val userId: String?,
    @Transient
    val capturedAtEpochMillis: Long = currentEpochMillis(),
)

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

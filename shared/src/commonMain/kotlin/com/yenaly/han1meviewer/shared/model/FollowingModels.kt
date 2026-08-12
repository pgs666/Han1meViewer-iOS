package com.yenaly.han1meviewer.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class MySubscriptions(
    val subscriptions: List<SubscriptionItem>,
    val subscriptionVideos: List<SubscriptionVideoItem>,
    val page: Int = 1,
    val hasNext: Boolean = false,
    val authRequired: Boolean = false,
)

@Serializable
data class SubscriptionItem(
    val artistName: String,
    val avatarUrl: String,
)

@Serializable
data class SubscriptionVideoItem(
    val title: String,
    val coverUrl: String,
    val videoCode: String,
    val duration: String? = null,
    val views: String? = null,
    val reviews: String? = null,
    val currentArtist: String? = null,
    val uploadTime: String? = null,
)

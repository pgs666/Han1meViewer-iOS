package com.yenaly.han1meviewer.shared.preferences

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Cross-platform key-value preferences store.
 * iOS implementation wraps UserDefaults; Android can wrap SharedPreferences.
 */
class PreferencesStore(
    private val storage: PreferencesStorage,
) {
    // Video playback
    val defaultVideoQuality = stringPref("default_video_quality", "1080P")
    val videoLanguage = stringPref("video_language", "cht")
    val playerSpeed = floatPref("player_speed", 1.0f)
    val allowResumePlayback = booleanPref("allow_resume_playback", true)
    val longPressSpeedTimes = floatPref("long_press_speed_times", 2.0f)

    // Domain
    val domainName = stringPref("domain_name", "https://hanime1.me")

    // UI
    val showPlayedIndicator = booleanPref("show_played_indicator", true)
    val showBottomProgress = booleanPref("show_bottom_progress", true)

    private fun stringPref(key: String, defaultValue: String) = PreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getString(k, def) },
        setter = { k, v -> storage.putString(k, v) },
    )

    private fun intPref(key: String, defaultValue: Int) = PreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getInt(k, def) },
        setter = { k, v -> storage.putInt(k, v) },
    )

    private fun floatPref(key: String, defaultValue: Float) = PreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getFloat(k, def) },
        setter = { k, v -> storage.putFloat(k, v) },
    )

    private fun booleanPref(key: String, defaultValue: Boolean) = PreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getBoolean(k, def) },
        setter = { k, v -> storage.putBoolean(k, v) },
    )
}

class PreferenceItem<T>(
    val key: String,
    val defaultValue: T,
    private val getter: (String, T) -> T,
    private val setter: (String, T) -> Unit,
) {
    private val _flow = MutableStateFlow(getter(key, defaultValue))

    val flow: Flow<T> = _flow.asStateFlow()

    fun get(): T = getter(key, defaultValue)

    fun set(value: T) {
        setter(key, value)
        _flow.value = value
    }
}

/**
 * Platform-specific storage backend.
 */
interface PreferencesStorage {
    fun getString(key: String, defaultValue: String): String
    fun putString(key: String, value: String)
    fun getInt(key: String, defaultValue: Int): Int
    fun putInt(key: String, value: Int)
    fun getFloat(key: String, defaultValue: Float): Float
    fun putFloat(key: String, value: Float)
    fun getBoolean(key: String, defaultValue: Boolean): Boolean
    fun putBoolean(key: String, value: Boolean)
}

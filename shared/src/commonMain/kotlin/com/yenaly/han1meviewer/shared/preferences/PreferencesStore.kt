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

    private fun stringPref(key: String, defaultValue: String) = StringPreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getString(k, def) },
        setter = { k, v -> storage.putString(k, v) },
    )

    private fun intPref(key: String, defaultValue: Int) = IntPreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getInt(k, def) },
        setter = { k, v -> storage.putInt(k, v) },
    )

    private fun floatPref(key: String, defaultValue: Float) = FloatPreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getFloat(k, def) },
        setter = { k, v -> storage.putFloat(k, v) },
    )

    private fun booleanPref(key: String, defaultValue: Boolean) = BooleanPreferenceItem(
        key, defaultValue,
        getter = { k, def -> storage.getBoolean(k, def) },
        setter = { k, v -> storage.putBoolean(k, v) },
    )
}

/**
 * Non-generic typed preference items.
 * These must NOT be generic because Kotlin/Native erases generic type parameters
 * when exporting to Swift, causing get() to return optional platform types
 * (NSString?, KotlinFloat?, KotlinBoolean?) instead of concrete non-optional types.
 */

class StringPreferenceItem(
    val key: String,
    val defaultValue: String,
    private val getter: (String, String) -> String,
    private val setter: (String, String) -> Unit,
) {
    private val _flow = MutableStateFlow(getter(key, defaultValue))
    val flow: Flow<String> = _flow.asStateFlow()

    fun get(): String = getter(key, defaultValue)

    fun set(value: String) {
        setter(key, value)
        _flow.value = value
    }
}

class IntPreferenceItem(
    val key: String,
    val defaultValue: Int,
    private val getter: (String, Int) -> Int,
    private val setter: (String, Int) -> Unit,
) {
    private val _flow = MutableStateFlow(getter(key, defaultValue))
    val flow: Flow<Int> = _flow.asStateFlow()

    fun get(): Int = getter(key, defaultValue)

    fun set(value: Int) {
        setter(key, value)
        _flow.value = value
    }
}

class FloatPreferenceItem(
    val key: String,
    val defaultValue: Float,
    private val getter: (String, Float) -> Float,
    private val setter: (String, Float) -> Unit,
) {
    private val _flow = MutableStateFlow(getter(key, defaultValue))
    val flow: Flow<Float> = _flow.asStateFlow()

    fun get(): Float = getter(key, defaultValue)

    fun set(value: Float) {
        setter(key, value)
        _flow.value = value
    }
}

class BooleanPreferenceItem(
    val key: String,
    val defaultValue: Boolean,
    private val getter: (String, Boolean) -> Boolean,
    private val setter: (String, Boolean) -> Unit,
) {
    private val _flow = MutableStateFlow(getter(key, defaultValue))
    val flow: Flow<Boolean> = _flow.asStateFlow()

    fun get(): Boolean = getter(key, defaultValue)

    fun set(value: Boolean) {
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

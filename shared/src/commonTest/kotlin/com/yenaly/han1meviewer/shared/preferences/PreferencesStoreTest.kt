package com.yenaly.han1meviewer.shared.preferences

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PreferencesStoreTest {
    @Test
    fun automaticQualityReductionIsOptInAndPersists() {
        val storage = MemoryPreferencesStorage()
        val preferences = PreferencesStore(storage)

        assertFalse(preferences.autoLowerQuality.get())
        preferences.autoLowerQuality.set(true)
        assertTrue(PreferencesStore(storage).autoLowerQuality.get())
    }

    @Test
    fun progressBarTapSeekingIsOnByDefaultAndPersists() {
        val storage = MemoryPreferencesStorage()
        val preferences = PreferencesStore(storage)

        assertTrue(preferences.tapProgressBarToSeek.get())
        preferences.tapProgressBarToSeek.set(false)
        assertFalse(PreferencesStore(storage).tapProgressBarToSeek.get())
    }

    @Test
    fun doubleTapSeekingDefaultsAndDirectionPersist() {
        val storage = MemoryPreferencesStorage()
        val preferences = PreferencesStore(storage)

        assertTrue(preferences.doubleTapSeeking.get())
        assertFalse(preferences.reverseDoubleTapSeeking.get())
        preferences.doubleTapSeeking.set(false)
        preferences.reverseDoubleTapSeeking.set(true)

        val reloaded = PreferencesStore(storage)
        assertFalse(reloaded.doubleTapSeeking.get())
        assertTrue(reloaded.reverseDoubleTapSeeking.get())
    }
}

private class MemoryPreferencesStorage : PreferencesStorage {
    private val values = mutableMapOf<String, Any>()

    override fun getString(key: String, defaultValue: String) = values[key] as? String ?: defaultValue
    override fun putString(key: String, value: String) { values[key] = value }
    override fun getInt(key: String, defaultValue: Int) = values[key] as? Int ?: defaultValue
    override fun putInt(key: String, value: Int) { values[key] = value }
    override fun getFloat(key: String, defaultValue: Float) = values[key] as? Float ?: defaultValue
    override fun putFloat(key: String, value: Float) { values[key] = value }
    override fun getBoolean(key: String, defaultValue: Boolean) = values[key] as? Boolean ?: defaultValue
    override fun putBoolean(key: String, value: Boolean) { values[key] = value }
}

package com.yenaly.han1meviewer.shared.preferences

import java.util.concurrent.ConcurrentHashMap

/**
 * In-memory JVM implementation for testing.
 */
class JvmPreferencesStorage : PreferencesStorage {
    private val strings = ConcurrentHashMap<String, String>()
    private val ints = ConcurrentHashMap<String, Int>()
    private val floats = ConcurrentHashMap<String, Float>()
    private val booleans = ConcurrentHashMap<String, Boolean>()

    override fun getString(key: String, defaultValue: String): String = strings.getOrDefault(key, defaultValue)
    override fun putString(key: String, value: String) { strings[key] = value }

    override fun getInt(key: String, defaultValue: Int): Int = ints.getOrDefault(key, defaultValue)
    override fun putInt(key: String, value: Int) { ints[key] = value }

    override fun getFloat(key: String, defaultValue: Float): Float = floats.getOrDefault(key, defaultValue)
    override fun putFloat(key: String, value: Float) { floats[key] = value }

    override fun getBoolean(key: String, defaultValue: Boolean): Boolean = booleans.getOrDefault(key, defaultValue)
    override fun putBoolean(key: String, value: Boolean) { booleans[key] = value }
}

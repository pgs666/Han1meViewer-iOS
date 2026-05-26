package com.yenaly.han1meviewer.shared.preferences

import platform.Foundation.NSUserDefaults

class IosPreferencesStorage(
    private val defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults,
) : PreferencesStorage {
    override fun getString(key: String, defaultValue: String): String =
        defaults.stringForKey(key) ?: defaultValue

    override fun putString(key: String, value: String) {
        defaults.setObject(value, forKey = key)
    }

    override fun getInt(key: String, defaultValue: Int): Int =
        defaults.integerForKey(key).toInt().takeIf { defaults.objectForKey(key) != null } ?: defaultValue

    override fun putInt(key: String, value: Int) {
        defaults.setInteger(value.toLong(), forKey = key)
    }

    override fun getFloat(key: String, defaultValue: Float): Float =
        defaults.floatForKey(key).takeIf { defaults.objectForKey(key) != null } ?: defaultValue

    override fun putFloat(key: String, value: Float) {
        defaults.setFloat(value, forKey = key)
    }

    override fun getBoolean(key: String, defaultValue: Boolean): Boolean =
        defaults.boolForKey(key).takeIf { defaults.objectForKey(key) != null } ?: defaultValue

    override fun putBoolean(key: String, value: Boolean) {
        defaults.setBool(value, forKey = key)
    }
}

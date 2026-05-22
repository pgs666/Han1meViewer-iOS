package com.yenaly.han1meviewer.shared.db

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver

actual class DatabaseDriverFactory {
    actual fun createDriver(): SqlDriver {
        return NativeSqliteDriver(Han1meDatabase.Schema, "han1me.db")
    }
}

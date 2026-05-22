package com.yenaly.han1meviewer.shared.db

import app.cash.sqldelight.db.SqlDriver

expect class DatabaseDriverFactory {
    fun createDriver(): SqlDriver
}

fun createDatabase(driverFactory: DatabaseDriverFactory): Han1meDatabase {
    return Han1meDatabase(driverFactory.createDriver())
}

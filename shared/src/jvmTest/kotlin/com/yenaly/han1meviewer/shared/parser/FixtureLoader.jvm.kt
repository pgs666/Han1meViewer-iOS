package com.yenaly.han1meviewer.shared.parser

actual fun loadParserFixtureOrNull(name: String): String? =
    object {}.javaClass.getResourceAsStream("/fixtures/$name")
        ?.bufferedReader()
        ?.use { it.readText() }

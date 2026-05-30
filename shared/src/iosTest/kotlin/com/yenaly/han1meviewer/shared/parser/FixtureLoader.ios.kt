package com.yenaly.han1meviewer.shared.parser

// Kotlin/Native test runs have no classpath resource loading; real-page
// regression fixtures are validated on the JVM CI run. Returns null so
// fixture-driven tests skip on iOS.
actual fun loadParserFixtureOrNull(name: String): String? = null

package com.yenaly.han1meviewer.shared.parser

/**
 * Loads a saved-HTML regression fixture by file name from
 * `commonTest/resources/fixtures/`. Returns null when the fixture is
 * absent (e.g. real captured pages haven't been dropped in yet, or the
 * platform — Kotlin/Native — has no classpath resource loading). Tests
 * are expected to skip gracefully when this returns null so the suite
 * stays green on the JVM CI run before real samples are added.
 *
 * See `commonTest/resources/fixtures/README.md` for how to capture real
 * pages and wire them into [ParserRegressionTest].
 */
expect fun loadParserFixtureOrNull(name: String): String?

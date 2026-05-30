package com.yenaly.han1meviewer.shared.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine

/** Minimal HttpClient over a [MockEngine] for repository request/response tests. */
fun testHttpClient(engine: MockEngine): HttpClient = HttpClient(engine)

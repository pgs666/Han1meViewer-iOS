package com.yenaly.han1meviewer.shared

import com.yenaly.han1meviewer.shared.test.runTest
import kotlin.test.Test
import kotlin.test.assertTrue

class SmokeTestTest {
    @Test
    fun fetchSomethingUsesRealHttp() = runTest {
        val result = SharedSmokeTest().fetchSomething()

        assertTrue(result.bodyLength > 0)
        assertTrue(result.containsExampleDomain)
    }
}

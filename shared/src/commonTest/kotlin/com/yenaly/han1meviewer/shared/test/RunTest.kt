package com.yenaly.han1meviewer.shared.test

import kotlinx.coroutines.test.runTest

fun runTest(block: suspend () -> Unit) = runTest { block() }

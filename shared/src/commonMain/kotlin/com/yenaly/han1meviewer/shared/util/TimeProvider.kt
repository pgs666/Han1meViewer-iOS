package com.yenaly.han1meviewer.shared.util

import kotlin.time.Clock

internal fun currentEpochMillis(): Long = Clock.System.now().toEpochMilliseconds()

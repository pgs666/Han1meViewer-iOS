package com.yenaly.han1meviewer.shared.util

import kotlin.time.Clock
import kotlin.time.ExperimentalTime

@OptIn(ExperimentalTime::class)
internal fun currentEpochMillis(): Long = Clock.System.now().toEpochMilliseconds()

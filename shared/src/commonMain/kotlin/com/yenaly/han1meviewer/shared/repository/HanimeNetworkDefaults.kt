package com.yenaly.han1meviewer.shared.repository

object HanimeNetworkDefaults {
    const val DEFAULT_BASE_URL = "https://hanime1.me"
    const val DEFAULT_USER_AGENT =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
            "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    /**
     * Backup domains in priority order, matching Android [HanimeConstants.HANIME_URL].
     * The first entry is the default/preferred domain.
     */
    val BACKUP_DOMAINS = listOf(
        "https://hanime1.me",
        "https://hanime1.com",
        "https://hanimeone.me",
        "https://javchu.com",
    )

    /**
     * Backup hostnames for URL matching, matching Android [HanimeConstants.HANIME_HOSTNAME].
     */
    val BACKUP_HOSTNAMES = listOf(
        "hanime1.me",
        "hanime1.com",
        "hanimeone.me",
        "javchu.com",
    )
}

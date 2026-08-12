package com.yenaly.han1meviewer.shared.session

import com.yenaly.han1meviewer.shared.db.DatabaseDriverFactory
import com.yenaly.han1meviewer.shared.db.createDatabase
import com.yenaly.han1meviewer.shared.model.SessionCookie
import com.yenaly.han1meviewer.shared.test.runTest
import kotlin.test.Test
import kotlin.test.assertTrue

class SqlDelightSessionStoreTest {
    @Test
    fun clearingLoginCookiesOnlyAffectsRequestedDomain() = runTest {
        val store = SqlDelightSessionStore(createDatabase(DatabaseDriverFactory()))
        store.saveCookies(
            listOf(
                SessionCookie(name = "hanime1_session", value = "dot-me", domain = ".hanime1.me"),
                SessionCookie(name = "cf_clearance", value = "dot-me-cf", domain = "hanime1.me"),
                SessionCookie(name = "hanime1_session", value = "dot-com", domain = "hanime1.com"),
                SessionCookie(name = "han1me_ios_web_login_confirmed", value = "true", domain = "hanime1.com"),
            )
        )

        store.clearLoginCookies("hanime1.me")

        val cookies = store.loadCookies()
        assertTrue(cookies.none { it.value == "dot-me" })
        assertTrue(cookies.any { it.value == "dot-me-cf" })
        assertTrue(cookies.any { it.value == "dot-com" })
        assertTrue(cookies.any { it.domain == "hanime1.com" && it.name == "han1me_ios_web_login_confirmed" })
    }
}

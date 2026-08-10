package com.yenaly.han1meviewer.shared.network

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class Han1meHttpClientTest {
    @Test
    fun cloudflareFooterTextIsNotAChallenge() {
        val body = "<html><footer>Protected by Cloudflare</footer></html>"

        assertFalse(body.hasCloudflareChallengeBody())
    }

    @Test
    fun cloudflareChallengeMarkersAreDetected() {
        val body = "<script>window._cf_chl_opt = {}</script>"

        assertTrue(body.hasCloudflareChallengeBody())
    }

    @Test
    fun cloudflareIpBlockPageIsDetected() {
        val body = """<title>Attention Required! | Cloudflare</title>
            <h1 data-translate="block_headline">Sorry, you have been blocked</h1>
            <span>Cloudflare Ray ID: abc123</span>"""

        assertTrue(body.hasCloudflareIpBlockBody())
        assertFalse("<footer>Protected by Cloudflare</footer>".hasCloudflareIpBlockBody())
    }
}

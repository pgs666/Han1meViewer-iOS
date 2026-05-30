# Parser regression fixtures

Real captured pages that lock down the manual KMP port of the upstream
Android `Parser.kt`. When the site / upstream changes its HTML, refresh
these and `ParserRegressionTest` will flag any divergence.

## Where to put files

Drop captured files here as JVM test resources:

```
shared/src/jvmTest/resources/fixtures/
  home.html        # GET https://hanime1.me/ (logged in)
  search.html      # GET https://hanime1.me/search?query=...
  video.html       # GET https://hanime1.me/watch?v=<code>
  comments.json    # GET https://hanime1.me/loadComment?type=video&id=<code>
```

`ParserRegressionTest` reads them via the classpath. Each test skips
(returns early) when its file is absent, so the suite stays green until
real samples are added. `loader-selftest.html` is a committed tiny
fixture that proves the loader path works.

## How to capture

1. Log in on a real device/browser at hanime1.me.
2. Save the raw HTML response (browser "View Source" / save, or
   `curl` with your session cookies — the site is behind Cloudflare so a
   real browser session is the reliable path).
3. Save with the file names above. Do **not** commit personal cookies or
   tokens — strip any `_token` / session values if you sanitize, but note
   the parser tests for CSRF token extraction expect an `input[name=_token]`
   to be present.

## Why JVM-only

Kotlin/Native test runs have no classpath resource loading, so fixtures
are validated on the `:shared:jvmTest` CI job. The iOS `actual` loader
returns null and the tests skip.

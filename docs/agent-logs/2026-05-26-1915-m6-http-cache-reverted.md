# M6: HTTP 缓存 — 回退

## What Changed
- Reverted HttpCache plugin addition — `HttpCache` is NOT in `ktor-client-core`
- Requires separate `ktor-client-plugins` dependency which was not added

## Why Changed
- CI failed with "Unresolved reference 'HttpCache'"
- Need to add `io.ktor:ktor-client-plugins` dependency first

## Verification
- CI failed (run 26437195353)

## Mistakes
- Incorrectly assumed HttpCache was in ktor-client-core. It requires ktor-client-plugins.

## Known Limits
- M6 remains unfixed until ktor-client-plugins dependency is added

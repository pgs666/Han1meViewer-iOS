# M6: HTTP 缓存 — 再次回退

## What Changed
- Fully reverted HttpCache plugin and ktor-client-plugins dependency

## Why Changed
- CI failed: "Could not find io.ktor:ktor-client-plugins:3.3.2"
- The artifact name `ktor-client-plugins` doesn't exist in Ktor 3.3.2
- HttpCache in Ktor 3.x may require a different artifact or be unavailable

## Verification
- CI failed (run 26437441615)

## Mistakes
- Assumed `ktor-client-plugins` was the correct artifact name without verifying

## Known Limits
- M6 (HTTP cache) cannot be implemented without finding the correct Ktor artifact
- Needs further investigation of Ktor 3.x HTTP cache module naming

# M6: HTTP 缓存 — 回退（Ktor 3.x 无 HttpCache 插件）

## What Changed
- 完全回退 HttpCache 相关改动

## Why Changed
- Ktor 3.3.2 没有 `ktor-client-plugins` 这个 artifact
- `HttpCache` 类在 `ktor-client-core` 中也找不到（KMP target 不导出）
- 可能是 Ktor 3.x 对 KMP 的 HttpCache 支持还不完整

## Verification
- 回退后 CI 通过 (run 26437614398)

## Mistakes
- 先假设 HttpCache 在 ktor-client-core 中 → 失败
- 又假设 ktor-client-plugins 存在 → 也失败
- 两次都未在本地验证 artifact 存在性

## Known Limits
- M6 在 Ktor 3.x KMP 项目中暂时无法实现
- 需要等 Ktor 完善 KMP HttpCache 支持，或自行实现应用层缓存

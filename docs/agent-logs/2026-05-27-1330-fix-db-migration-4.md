# 修复 WatchHistory 数据库迁移缺失 — release_date_epoch_millis

日期：2026-05-27 13:30 CST

## User Input

```text
error while compiling: SELECT watch_history.video_code, ... watch_history.release_date_epoch_millis
FROM watch_history WHERE video_code = ?
no such column: watch_history.release_date_epoch_millis
参考安卓版的视频解析，修复它
```

## 问题分析

`WatchHistory.sq` 的 CREATE TABLE 定义了 `release_date_epoch_millis` 列，但缺少对应的 `4.sqm` 迁移文件。

已有数据库（schema version 3）在升级时找不到该列，导致 SQLDelight 编译报错 `no such column`。

Android 版 `WatchHistory.sq` 没有 `release_date_epoch_millis` 列，这是 iOS 独有的扩展。

## 修改内容

### 新增文件

- `shared/src/commonMain/sqldelight/com/yenaly/han1meviewer/shared/db/4.sqm`

```sql
ALTER TABLE watch_history ADD COLUMN release_date_epoch_millis INTEGER NOT NULL DEFAULT 0;
```

## 验证

- [x] `:shared:jvmTest` 通过
- [x] CI (run 26493855998) jvmTest + iOS build 通过

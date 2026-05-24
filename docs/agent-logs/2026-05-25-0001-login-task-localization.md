# Login Validation, Task Cancellation, And Localization

## User Request

修 iOS 侧：登录真实性校验 + 全局 ViewModel 任务取消模式 + 残留乱码。修复乱码的时候：顺便把硬编码的所有UI文字变成支持多语言的

## English Translation

Fix the iOS side: real login validation, global ViewModel task cancellation pattern, and remaining garbled text. While fixing garbled text, also convert all hardcoded UI text to support localization.

## Planned Changes

- Validate imported web login cookies through the home repository before marking the session as logged in.
- Add cancellable tasks and stale-result guards to Swift ViewModels.
- Add iOS localization resources and replace hardcoded UI strings with localized keys.

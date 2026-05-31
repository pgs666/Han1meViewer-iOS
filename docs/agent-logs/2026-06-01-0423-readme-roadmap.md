# Add Roadmap to README + dedicated ROADMAP.md

## User Input

Original:

```text
看看Android版的代码，我还缺少了什么？
...
在readme里面写上roadmap，之后再做
...
a，a，c：readme写精简版，然后建立独立roadmap文档，把feature文档中的路线图删掉
...
开始做吧，然后readme中的路线图用checkbox就行
```

English translation:

```text
Look at the Android version's code — what am I still missing?
...
Write a roadmap into the README; we'll do the work later.
...
a, a, c: README gets a slim version; create a dedicated roadmap doc; delete the roadmap from the FEATURES doc.
...
Go ahead and start; and use checkboxes for the roadmap in the README.
```

## What Changed

- Created `docs/ROADMAP.md` as the single source of truth for the roadmap:
  - Table 1 "计划移植" (planned ports): manual/QR cookie import, playlist write
    operations, user account page, monthly preview — with priority, notes,
    shared-layer status, and the Android counterpart screen.
  - Table 2 "明确不做" (explicitly excluded): daily check-in (forbidden by
    AGENT_WORKING_RULES.md), HKeyframe / SharedHKeyframes, mpv settings,
    Firebase / Android update channel / Widget / WorkManager.
  - Table 3 "细粒度设置项差距": search grid columns, home horizontal card count.
- `docs/FEATURES.md`: removed the trailing "## 待实现 / 路线图" table, replaced
  with a one-line link to `ROADMAP.md`.
- `README.md`: added a slim `## 🗺️ 路线图` section (checkbox list of the 4
  planned ports) after the docs section, linking to `docs/ROADMAP.md`; removed
  "+ 路线图" from the FEATURES description in the docs list.
- `README.en.md`: matching `## 🗺️ Roadmap` section; removed "+ roadmap" from
  the FEATURES description.

## Why

The roadmap previously lived only inside `docs/FEATURES.md`. The user wanted it
surfaced in the README and consolidated into a dedicated document, derived from
a fresh Android↔iOS feature-gap comparison. Keeping a single authoritative
ROADMAP.md avoids the roadmap drifting across multiple files.

## Mistakes Or Failed Attempts

- None.

## Verification

- Docs-only change. Confirmed each edit applied exactly once. README links point
  to `docs/ROADMAP.md`; FEATURES links to `ROADMAP.md` (same dir). No code or
  build files touched, so `[skip ci]` is used and no CI/jvmTest run is needed.

## Known Limits

- The roadmap reflects the gap analysis at this point in time; it should be
  updated as features are ported or scope changes.

# Adaptive Related Cover Layout

## User Input

Original:

```text
那能判断当前页面吗 https://hanime1.me/watch?v=407591 类似于这种页面，下方的封面全都是竖版的，但是默认卡片形状对不上，所以会看到卡片变形的过程，包括iPad版的页面也是，我希望iPad检测到这种竖版封面的详情页相关影片侧边栏也变成双列卡片，而iPhone上检测到就变成三列
```

English translation:

```text
Can it detect the current page? On pages like https://hanime1.me/watch?v=407591, all related covers below are portrait, but the default card shape does not match, so the cards visibly deform while loading. This also affects iPad. When iPad detects this kind of portrait-cover detail page, make the related-video sidebar a two-column card grid; on iPhone, make it three columns.
```

## Investigation

- The referenced page uses simplified related-video cards under `#related-tabcontent`.
- Their images use the site's portrait cover form (`/image/cover/...`) and the site lays them out at `268:394`.
- The KMP parser already marks this DOM form as `HanimeItemType.Simplified`, but that information previously stopped before the SwiftUI detail snapshot.

## What Changed

- Added a detail-level portrait-related-cover flag derived from the majority of parsed related items being `Simplified`.
- Propagated the flag through KMP `VideoDetailSnapshot` into the Swift screen snapshot.
- iPhone/non-sidebar portrait-related grids now use three columns and `268:394` covers.
- The wide iPad related sidebar switches from horizontal rows to a two-column portrait card grid.
- Normal landscape-related pages keep their existing two-column phone grid and row-based iPad sidebar.
- Portrait cards omit the landscape-only metadata spacer, keeping the narrower grid compact.

## Verification

- Added a parser regression test using the referenced page's simplified portrait-card DOM shape.
- Local `:shared:jvmTest` could not enter compilation because the machine only has a Java 25 runtime without `javac`; CI supplies the required full JDK 21.
- Final KMP tests and iOS device compilation are performed by GitHub Actions after push.

## Known Limits

- Classification follows the page's DOM/card semantics rather than waiting for every remote image to download and measuring pixels. This prevents the visible layout deformation during image loading.

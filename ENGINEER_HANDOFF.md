# For X iOS engineers

DraftJSNative reads Draft.js `content_state` into Swift values and renders an Article body with SwiftUI. The package is MIT-licensed and has no dependencies or X credentials. It accepts the `entities` array in X's public Article API examples and the `entityMap` form observed in one published Article response.

## Try the package

```sh
swift test
swift run draftjs-native Examples/sample-article-envelope.json
swift run draftjs-native --check-roundtrip Examples/sample-article-envelope.json
Scripts/package_preview.sh
open /private/tmp/DraftJSNativePreview.app
```

The sample is synthetic. It includes mixed Hebrew and English, complex emoji, links, lists, a two-image gallery, a table, code, an embedded-post reference, a video poster, and LaTeX. The CLI prints Markdown and reports what the default native renderer cannot finish.

In an iOS host, extract the Article result from your authorized response and decode it:

```swift
let article = try DraftArticlePayload(jsonData: articleResultJSON)
let view = DraftArticleView(
    title: article.title,
    document: article.document,
    coverURL: article.coverMedia?.imageURL,
    mediaURLForID: { article.imageURL(forMediaID: $0) },
    atomicViewForEntity: { entity in
        // Return the host's native post, media, or math view when available.
        nil
    }
)
```

`DraftDocument` is available when the host already has the raw `content_state`. The parser validates UTF-16 style and entity ranges before rendering. Unknown block data and entity data remain available to the host.

## What has been verified

- Public synthetic fixtures and parser tests cover Draft.js and X field spellings, UTF-16 ranges, mixed direction text, gallery item preservation, Markdown conversion, and malformed data.
- A locally captured published Article result with 18 blocks and 9 entities decodes through `DraftArticlePayload` and converts without parser errors. That payload stays outside the repository.
- `DraftArticleArchive` preserves the complete JSON value tree through decode and encode. Semantic round trips pass on the public synthetic Article and two local Article payloads. A synthetic UTF-16 block text edit round trip passes; X's editor behavior has not been compared.
- The macOS preview displays the local Article's title, cover, text, image, caption, lists, code, and divider. The preview also exposed a paragraph truncation bug, which has been fixed and visually rechecked with the synthetic Article.
- The library builds for the iOS 16 simulator target. This is compile proof; it is not an iPhone runtime comparison.

## What blocks full parity

The default view uses a link for an embedded post and a poster for video or GIF media unless the host supplies a playable stream URL. It cannot supply X's post data, playback streams, author controls, or Article actions. LaTeX and uncommon atomic content need a native host renderer. Simple pipe tables and image galleries render, but their exact layout and interaction have not been compared with X on iPhone. The package preserves Article JSON values and supports limited block text edits, but has no native editor UI, full entity editing, undo/redo, media upload, or draft save/publish integration.

To finish the replacement, I need redacted `content_state` and companion media metadata for each Article feature, plus the expected iOS output at fixed viewport and text settings. A small host-side adapter for X's existing post and media components would let the package render those entities without copying private implementation into this repository. Editing needs its own contract for content-state serialization and the draft lifecycle.

The current feature-by-feature record and acceptance checks are in [PARITY.md](PARITY.md). Please treat this as a working reader prototype and a concrete starting point for parity work, not a claim that X can replace its renderer today.

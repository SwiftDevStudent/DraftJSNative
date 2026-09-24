# DraftJSNative

A dependency-free Swift parser and read-only SwiftUI renderer for Draft.js raw content states. It is aimed at native X Article clients, but is an independent project and is not affiliated with X.

The parser accepts standard Draft.js `entityMap` and camelCase fields, X's documented `entities` array, and an observed `entity_map`/snake_case variant. It validates UTF-16 style and entity ranges, preserves unknown block and entity metadata, and reports unsupported content during Markdown conversion. It does not fetch Article data from X or include authentication.

## Try it

Requirements: Swift 6, macOS 13 or iOS 16 for the library. The preview app runs on macOS.

```sh
git clone https://github.com/SwiftDevStudent/DraftJSNative.git
cd DraftJSNative
swift run draftjs-native Examples/sample-article.json
swift run draftjs-native Examples/sample-article-envelope.json
swift run draftjs-native --check-roundtrip Examples/sample-article-envelope.json
```

The synthetic samples mix Hebrew, English, flags, skin tones, and multi-person emoji sequences to exercise UTF-16 ranges. The second file is an Article envelope with a title, media metadata, and a longer body. The command prints Markdown and reports features that need a host component. Supply a raw Draft.js `content_state` or Article-result JSON file to convert your own article. An X Article URL or webpage HTML is not that JSON.

To open the native macOS sample window:

```sh
Scripts/package_preview.sh
open /private/tmp/DraftJSNativePreview.app
```

The preview opens the synthetic Article envelope by default. The script uses the active Xcode toolchain unless `DEVELOPER_DIR` is set. It accepts `DRAFTJS_PREVIEW_APP_PATH` and `SWIFT_SCRATCH_PATH` to change its output paths. You can pass another Article envelope JSON path to the preview executable.

## Add the package

In Xcode, add `https://github.com/SwiftDevStudent/DraftJSNative.git` as a Swift package dependency and link the `DraftJSNative` library product. With a tagged release, SwiftPM can use:

```swift
.package(url: "https://github.com/SwiftDevStudent/DraftJSNative.git", from: "0.1.0")
```

Decode an Article result and display it:

```swift
import DraftJSNative
import SwiftUI

let article = try DraftArticlePayload(jsonData: articleResultJSON)
let view = DraftArticleView(
    title: article.title,
    document: article.document,
    coverURL: article.coverMedia?.imageURL,
    mediaURLForID: { article.imageURL(forMediaID: $0) }
)

let requirements = article.document.defaultRendererWarnings { mediaID in
    article.imageURL(forMediaID: mediaID)
}
print(requirements)
```

The input is the Article result containing `title`, `content_state`, and optional `cover_media` and `media_entities`. A host app extracts that result from its own authorized network response. For raw Draft.js data, use `DraftDocument(jsonData:)` directly. Convert either document to Markdown with `document.markdown(mediaURLForID:)`. If the host can resolve a video or GIF stream, pass `playbackURLForID` to `DraftArticleView` for native AVKit playback.

To use the host app's existing post, video, GIF, or math components, provide `atomicViewForEntity`:

```swift
DraftArticleView(
    title: article.title,
    document: article.document,
    coverURL: article.coverMedia?.imageURL,
    mediaURLForID: { article.imageURL(forMediaID: $0) },
    atomicViewForEntity: { entity in
        // Return an AnyView from the host's native renderer, or nil for the built-in view.
        nil
    }
)
```

`DraftArticleView` handles paragraphs, headings, quotes, lists, code panels, simple Markdown tables, inline styles, links, dividers, captions, and image galleries when the host supplies URLs. System text layout supports mixed Hebrew, English, and emoji. The host owns Article loading, navigation, authentication, and interactions. See [ENGINEER_HANDOFF.md](ENGINEER_HANDOFF.md) for integration and verification steps.

For a semantic JSON round trip that retains unknown Article fields, decode with `DraftArticleArchive(jsonData:)` and call `jsonData()`. This may change whitespace and object key order. It does not implement editing.

## Current limits

This remains a prototype, **not a one-to-one or drop-in replacement** for X's Article renderer. Embedded posts use a link fallback. Video and GIF items play when the host supplies stream URLs; otherwise they show posters. LaTeX and other unknown atomic types need host renderers. The built-in table renderer covers simple pipe tables, not every Markdown table variant. The package is read-only; it does not implement editing or publishing. X's Article response shape is not a stable public contract for this package. See [PARITY.md](PARITY.md) for feature coverage and acceptance gates.

Article payloads captured during development are kept outside this repository. The public sample and tests use synthetic data. If a client renders `MARKDOWN` entity content as HTML, apply its normal untrusted-content sanitization.

References: [Draft.js data conversion](https://draftjs.org/docs/api-reference-data-conversion/), [Draft.js content blocks](https://draftjs.org/docs/api-reference-content-block/), and [X Articles API documentation](https://docs.x.com/x-api/articles/introduction).

Run tests with `swift test`. If your environment restricts SwiftPM's sandbox, use `swift test --disable-sandbox`.

## License

[MIT](LICENSE). You may use, modify, and distribute the package, including commercially, while preserving the copyright and license notice.

# DraftJSNative

A dependency-free Swift parser and read-only SwiftUI renderer for Draft.js raw content states. It is aimed at native X Article clients, but is an independent project and is not affiliated with X.

The parser accepts standard Draft.js `entityMap` and camelCase fields, X's documented `entities` array, and an observed `entity_map`/snake_case variant. It validates UTF-16 style and entity ranges, preserves unknown block and entity metadata, and reports unsupported content during Markdown conversion. It does not fetch Article data from X or include authentication.

## Try it

Requirements: Swift 6, macOS 13 or iOS 16 for the library. The preview app runs on macOS.

```sh
git clone https://github.com/SwiftDevStudent/DraftJSNative.git
cd DraftJSNative
swift run draftjs-native Examples/sample-article.json
```

The synthetic sample mixes Hebrew, English, flags, skin tones, and multi-person emoji sequences to exercise UTF-16 ranges. The command prints Markdown. Supply a raw Draft.js `content_state` JSON file to convert your own article. An X Article URL or webpage HTML is not that JSON.

To open the native macOS sample window:

```sh
Scripts/package_preview.sh
open /private/tmp/DraftJSNativePreview.app
```

The script uses the active Xcode toolchain unless `DEVELOPER_DIR` is set. It accepts `DRAFTJS_PREVIEW_APP_PATH` and `SWIFT_SCRATCH_PATH` to change its output paths. You can pass an Article envelope JSON path to the preview executable to supply a title, cover, and media URLs.

## Add the package

In Xcode, add `https://github.com/SwiftDevStudent/DraftJSNative.git` as a Swift package dependency and link the `DraftJSNative` library product. With a tagged release, SwiftPM can use:

```swift
.package(url: "https://github.com/SwiftDevStudent/DraftJSNative.git", from: "0.1.0")
```

Parse and convert:

```swift
import DraftJSNative

let document = try DraftDocument(jsonData: articleContentStateJSON)
for block in document.blocks {
    for run in document.runs(in: block) {
        // Render run.text using run.styles and run.entity.
    }
}

let result = document.markdown { mediaID in
    articleMediaURLs[mediaID] // URL? supplied by your app
}
print(result.text)
print(result.warnings)
```

Display the document in SwiftUI:

```swift
import DraftJSNative
import SwiftUI

DraftArticleView(title: articleTitle, document: document) { mediaID in
    articleMediaURLs[mediaID]
}
```

`DraftArticleView` handles paragraphs, headings, quotes, lists, code panels, inline styles, links, dividers, and images when the host supplies URLs. System text layout supports mixed Hebrew, English, and emoji. The host owns article loading, navigation, authentication, and interactions. For atomic content that needs a host component, pass `atomicViewForEntity` and return an `AnyView` for an entity you handle.

## Current limits

This is a `0.1.0` prototype, **not a one-to-one or drop-in replacement** for X's Article renderer. Embedded posts use a link fallback. Video, GIFs, galleries, LaTeX, Markdown tables, and X's surrounding Article UI need additional native rendering and host data. The package is read-only; it does not implement editing or publishing. X's Article response shape is not a stable public contract for this package. See [PARITY.md](PARITY.md) for feature coverage and acceptance gates.

Article payloads captured during development are kept outside this repository. The public sample and tests use synthetic data. If a client renders `MARKDOWN` entity content as HTML, apply its normal untrusted-content sanitization.

References: [Draft.js data conversion](https://draftjs.org/docs/api-reference-data-conversion/), [Draft.js content blocks](https://draftjs.org/docs/api-reference-content-block/), and [X Articles API documentation](https://docs.x.com/x-api/articles/introduction).

Run tests with `swift test`. If your environment restricts SwiftPM's sandbox, use `swift test --disable-sandbox`.

## License

[MIT](LICENSE). You may use, modify, and distribute the package, including commercially, while preserving the copyright and license notice.

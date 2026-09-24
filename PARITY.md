# X Article display parity

Target: native Article reading and editing with feature parity. The current SwiftUI view covers part of the read-only display target and is not a drop-in replacement.

## Evidence

- X's [Articles help](https://help.x.com/en/using-x/articles) lists images, video, GIFs, embedded posts, links, headings, subheadings, bold, italics, strikethrough, indentation, and numbered/bulleted lists.
- X's [draft Article API](https://docs.x.com/x-api/articles/create-draft-article) additionally names atomic Markdown/code/tables, dividers, LaTeX, and emoji. Its entity data includes `post_id`, `media_items`, `markdown`, and `caption`.
- Development included a local parse of one published Article payload and a macOS visual comparison. The captured payload is kept outside this package. Public tests use synthetic fixtures, including a complete Article envelope.

| Feature | Parser | Native view | Remaining work |
| --- | --- | --- | --- |
| Paragraphs, line breaks, Hebrew/English/emoji | Decoded | Rendered | Compare iOS device layout with X. |
| Headings, bold, italic, strikethrough | Decoded | Rendered | Verify typography with more Article variants. |
| Links | Decoded | Rendered | Verify X navigation behavior in a host app. |
| Numbered/bulleted lists and depth | Decoded | Rendered | Compare nested spacing and indentation. |
| Cover and inline images | ID and metadata available | Rendered when host supplies URLs | Compare image crops, loading, and accessibility. |
| Image captions | Decoded | Rendered | Compare placement and styling. |
| Atomic code fences | Source preserved | Native scrollable code panel | Syntax highlighting and Copy control. |
| Atomic Markdown tables and other Markdown | Source preserved | Simple pipe tables rendered natively; other Markdown partial | Compare table variants, alignment, and formatting. |
| Dividers | Decoded | Rendered | Compare spacing and style. |
| Embedded posts | Post ID decoded | Link fallback; host render hook available | Native post component and post lookup. |
| GIF and video | Entity metadata preserved | AVKit playback when host supplies a stream URL; poster otherwise | Verify X stream resolution, playback, poster, captions, accessibility, and iPhone behavior. |
| Image galleries | Every media item decoded | Two-column native grid | Compare X's layouts, crops, taps, and accessibility for each gallery size. |
| LaTeX and atomic emoji | Entity metadata preserved | Missing | Native renderers and real examples. |
| Article JSON round trip | Full JSON tree retained | Not applicable | Semantic round trip passes synthetic and two local payloads; edit round trips remain missing. |
| Article navigation, sharing, reactions, author and audience UI | Outside `content_state` | Missing | Host app integration. |
| Editing, undo/redo, draft save/publish | Raw content state decoded; unchanged Article JSON can round-trip | Missing | Native editor, edit serialization, media upload, X authorization and save/publish integration. |

## One-to-one acceptance gates

1. Obtain authorized raw fixtures for every Article feature above, including mixed Hebrew/English/emoji and media variants.
2. For each fixture, assert that parsing preserves text, UTF-16 ranges, entity associations, block order, and metadata without silent fallback.
3. Compare iOS native output with X at the same viewport, text size, color scheme, and content. Check typography, spacing, direction, captions, media crops, embeds, interaction, and accessibility.
4. Resolve the missing host inputs: Article media URLs, post data, playback streams, navigation and interaction handlers, and any private rendering rules. The library cannot manufacture those from `content_state` alone.
5. Validate editing, undo/redo, serialization, media upload, and draft lifecycle against X's actual client behavior before calling this a complete replacement.

The local published Article parses through `DraftArticlePayload` and renders in a macOS preview. Its embedded post remains a link fallback. The iOS library builds, but iOS runtime, editing, and one-to-one feature or pixel parity remain unverified.

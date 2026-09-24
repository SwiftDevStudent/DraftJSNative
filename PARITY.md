# X Article display parity

Target: read-only native display of an X Article from its `content_state` and companion Article metadata. The current SwiftUI view is a prototype, not a drop-in replacement.

## Evidence

- X's [Articles help](https://help.x.com/en/using-x/articles) lists images, video, GIFs, embedded posts, links, headings, subheadings, bold, italics, strikethrough, indentation, and numbered/bulleted lists.
- X's [draft Article API](https://docs.x.com/x-api/articles/create-draft-article) additionally names atomic Markdown/code/tables, dividers, LaTeX, and emoji. Its entity data includes `post_id`, `media_items`, `markdown`, and `caption`.
- Development included a local parse of one published Article payload and a macOS visual comparison. The captured payload is kept outside this package. Public tests use synthetic fixtures.

| Feature | Parser | Native view | Remaining work |
| --- | --- | --- | --- |
| Paragraphs, line breaks, Hebrew/English/emoji | Decoded | Rendered | Compare iOS device layout with X. |
| Headings, bold, italic, strikethrough | Decoded | Rendered | Verify typography with more Article variants. |
| Links | Decoded | Rendered | Verify X navigation behavior in a host app. |
| Numbered/bulleted lists and depth | Decoded | Rendered | Compare nested spacing and indentation. |
| Cover and inline images | ID and metadata available | Rendered when host supplies URLs | Compare image crops, loading, and accessibility. |
| Image captions | Decoded | Rendered | Compare placement and styling. |
| Atomic code fences | Source preserved | Native scrollable code panel | Syntax highlighting and Copy control. |
| Atomic Markdown tables and other Markdown | Source preserved | Partial | Native table layout. |
| Dividers | Decoded | Rendered | Compare spacing and style. |
| Embedded posts | Post ID decoded | Link fallback; host render hook available | Native post component and post lookup. |
| GIF and video | Entity metadata preserved | Host render hook available | Native playback, poster frames, captions, accessibility. |
| Image galleries | Entity metadata preserved | Missing | Multiple-image layout and interaction. |
| LaTeX and atomic emoji | Entity metadata preserved | Missing | Native renderers and real examples. |
| Article navigation, sharing, reactions, author and audience UI | Outside `content_state` | Missing | Host app integration. |
| Editing, undo/redo, draft save/publish | Outside display target | Missing | Separate native editor and X integration. |

## One-to-one acceptance gates

1. Obtain authorized raw fixtures for every Article feature above, including mixed Hebrew/English/emoji and media variants.
2. For each fixture, assert that parsing preserves text, UTF-16 ranges, entity associations, block order, and metadata without silent fallback.
3. Compare iOS native output with X at the same viewport, text size, color scheme, and content. Check typography, spacing, direction, captions, media crops, embeds, interaction, and accessibility.
4. Resolve the missing host inputs: Article media URLs, post data, navigation and interaction handlers, and any private rendering rules. The library cannot manufacture those from `content_state` alone.

The local published Article parsed and rendered in a macOS preview. This does **not** establish one-to-one feature or pixel parity on iOS.

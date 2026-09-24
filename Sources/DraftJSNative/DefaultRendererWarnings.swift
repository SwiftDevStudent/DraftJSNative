import Foundation

extension DraftDocument {
    /// Features that the built-in SwiftUI view cannot display completely.
    /// A host may satisfy these by supplying `atomicViewForEntity`.
    public func defaultRendererWarnings(
        mediaURLForID: (String) -> URL? = { _ in nil },
        playbackURLForID: (String) -> URL? = { _ in nil }
    ) -> [String] {
        var warnings: [String] = []
        let knownBlocks: Set<String> = [
            "unstyled", "paragraph", "header-one", "header-two", "header-three",
            "header-four", "header-five", "header-six", "blockquote",
            "unordered-list-item", "ordered-list-item", "code-block", "atomic"
        ]
        let knownStyles: Set<String> = ["BOLD", "ITALIC", "STRIKETHROUGH", "UNDERLINE", "CODE"]

        for block in blocks {
            if !knownBlocks.contains(block.type) {
                warnings.append("Block \(block.key) uses unsupported type \(block.type)")
            }
            for style in Set(block.inlineStyleRanges.map { $0.style.uppercased() }).sorted()
                where !knownStyles.contains(style) {
                warnings.append("Block \(block.key) uses unsupported style \(style)")
            }
            if block.type != "atomic" {
                for key in Set(block.entityRanges.map(\.key)).sorted() {
                    if let entity = entities[key], entity.type.uppercased() != "LINK" {
                        warnings.append("Block \(block.key) needs an inline \(entity.type) renderer")
                    }
                }
                continue
            }

            guard let key = block.entityRanges.first(where: { $0.length > 0 })?.key,
                  let entity = entities[key] else {
                warnings.append("Atomic block \(block.key) has no entity")
                continue
            }
            switch entity.type.uppercased() {
            case "DIVIDER": break
            case "TWEET":
                warnings.append("Block \(block.key) needs a native embedded post component")
            case "MEDIA":
                if entity.mediaItems.isEmpty {
                    warnings.append("Block \(block.key) has no usable media items")
                }
                for item in entity.mediaItems {
                    if mediaURLForID(item.mediaID) == nil {
                        warnings.append("Media \(item.mediaID) needs a URL from the host")
                    }
                    let category = item.category?.lowercased() ?? ""
                    if (category.contains("video") || category.contains("gif"))
                        && playbackURLForID(item.mediaID) == nil {
                        warnings.append("Media \(item.mediaID) needs native playback from the host")
                    }
                }
            case "MARKDOWN":
                guard let source = entity.data["markdown"]?.stringValue else {
                    warnings.append("Block \(block.key) has no Markdown source")
                    continue
                }
                let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
                if DraftMarkdownTable(markdown: source) == nil,
                   !(trimmed.hasPrefix("```") && trimmed.hasSuffix("```")) {
                    warnings.append("Block \(block.key) uses fallback Markdown display")
                }
            default:
                warnings.append("Block \(block.key) needs a native \(entity.type) renderer")
            }
        }
        return warnings
    }
}

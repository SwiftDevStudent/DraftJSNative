import Foundation

public struct MarkdownConversion {
    public let text: String
    /// Features that need app-specific handling or could not be represented faithfully.
    public let warnings: [String]
}

extension DraftDocument {
    /// Converts supported blocks to Markdown. Media URLs are often stored outside `content_state`.
    public func markdown(mediaURLForID: (String) -> URL? = { _ in nil }) -> MarkdownConversion {
        var lines: [String] = []
        var warnings: [String] = []
        var orderedCounters: [Int: Int] = [:]

        for block in blocks {
            if block.type == "atomic" {
                lines.append(renderAtomic(block, mediaURLForID: mediaURLForID, warnings: &warnings))
                continue
            }

            let useInlineHTML = block.inlineStyleRanges.enumerated().contains { index, first in
                block.inlineStyleRanges.dropFirst(index + 1).contains { second in
                    first.length > 0 && second.length > 0
                        && first.offset < second.offset + second.length
                        && second.offset < first.offset + first.length
                        && (first.offset != second.offset || first.length != second.length)
                }
            }
            if useInlineHTML {
                warnings.append("Overlapping styles use inline HTML in block \(block.key)")
            }

            let content = runs(in: block).map { run -> String in
                let styles = run.styles.map { $0.uppercased() }
                for style in styles where !["BOLD", "ITALIC", "STRIKETHROUGH", "CODE"].contains(style) {
                    warnings.append("Unsupported inline style \(style) in block \(block.key)")
                }
                var result = useInlineHTML ? escapeHTML(run.text) : escapeMarkdown(run.text)
                if useInlineHTML {
                    if styles.contains("CODE") { result = "<code>\(result)</code>" }
                    if styles.contains("BOLD") { result = "<strong>\(result)</strong>" }
                    if styles.contains("ITALIC") { result = "<em>\(result)</em>" }
                    if styles.contains("STRIKETHROUGH") { result = "<del>\(result)</del>" }
                } else {
                    if styles.contains("CODE") {
                        let ticks = String(repeating: "`", count: longestBacktickRun(in: run.text) + 1)
                        let padding = run.text.hasPrefix("`") || run.text.hasSuffix("`") ? " " : ""
                        result = "\(ticks)\(padding)\(run.text)\(padding)\(ticks)"
                    }
                    if styles.contains("BOLD") { result = "**\(result)**" }
                    if styles.contains("ITALIC") { result = "*\(result)*" }
                    if styles.contains("STRIKETHROUGH") { result = "~~\(result)~~" }
                }
                if let entity = run.entity {
                    if entity.type.uppercased() == "LINK" {
                        if let url = entity.data["url"]?.stringValue
                            ?? entity.data["href"]?.stringValue,
                           let parsed = URL(string: url),
                           ["https", "http", "mailto"].contains(parsed.scheme?.lowercased() ?? "") {
                            if useInlineHTML {
                                result = "<a href=\"\(escapeHTML(url))\">\(result)</a>"
                            } else {
                                result = "[\(result)](<\(url.replacingOccurrences(of: ">", with: "%3E"))>)"
                            }
                        } else {
                            warnings.append("LINK without a usable URL in block \(block.key)")
                        }
                    } else {
                        warnings.append("Unsupported inline entity \(entity.type) in block \(block.key)")
                    }
                }
                return result
            }.joined()

            switch block.type {
            case "unstyled", "paragraph": lines.append(content)
            case "header-one": lines.append("# \(content)")
            case "header-two": lines.append("## \(content)")
            case "header-three": lines.append("### \(content)")
            case "header-four": lines.append("#### \(content)")
            case "header-five": lines.append("##### \(content)")
            case "header-six": lines.append("###### \(content)")
            case "blockquote": lines.append("> \(content)")
            case "unordered-list-item":
                lines.append("\(String(repeating: "  ", count: max(0, block.depth)))- \(content)")
            case "ordered-list-item":
                let depth = max(0, block.depth)
                let next = (orderedCounters[depth] ?? 0) + 1
                orderedCounters[depth] = next
                lines.append("\(String(repeating: "  ", count: depth))\(next). \(content)")
            case "code-block": lines.append("```\n\(block.text)\n```")
            default:
                warnings.append("Unsupported block type \(block.type) in block \(block.key)")
                lines.append(content)
            }
            if block.type != "ordered-list-item" {
                orderedCounters.removeAll()
            }
        }

        return MarkdownConversion(text: lines.joined(separator: "\n\n"), warnings: warnings)
    }

    private func renderAtomic(
        _ block: DraftBlock,
        mediaURLForID: (String) -> URL?,
        warnings: inout [String]
    ) -> String {
        guard let key = block.entityRanges.first(where: { $0.length > 0 })?.key,
              let entity = entities[key] else {
            warnings.append("Atomic block \(block.key) has no entity")
            return "[Unsupported atomic content]"
        }
        switch entity.type.uppercased() {
        case "DIVIDER": return "---"
        case "MARKDOWN":
            if let markdown = entity.data["markdown"]?.stringValue { return markdown.trimmingCharacters(in: .newlines) }
        case "TWEET":
            if let id = entity.data["post_id"]?.stringValue
                ?? entity.data["tweet_id"]?.stringValue
                ?? entity.data["tweetId"]?.stringValue {
                if !id.isEmpty && id.allSatisfy(\.isNumber) {
                    return "https://x.com/i/status/\(id)"
                }
            }
        case "MEDIA":
            let items = entity.data["media_items"] ?? entity.data["mediaItems"]
            if case .array(let values) = items,
               case .object(let item)? = values.first,
               let id = item["media_id"]?.stringValue ?? item["mediaId"]?.stringValue {
                if let url = mediaURLForID(id) { return "![Media](<\(url.absoluteString)>)" }
                warnings.append("Media \(id) needs a URL from article metadata")
                return "[Media: \(escapeMarkdown(id))]"
            }
        default: break
        }
        warnings.append("Unsupported atomic entity \(entity.type) in block \(block.key)")
        return "[Unsupported \(entity.type) content]"
    }
}

private func escapeMarkdown(_ text: String) -> String {
    let special = Set("\\`*_{}[]()#+-.!>|~")
    return text.reduce(into: "") { output, character in
        if special.contains(character) { output.append("\\") }
        output.append(character)
    }
}

private func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private func longestBacktickRun(in text: String) -> Int {
    var longest = 0
    var current = 0
    for character in text {
        current = character == "`" ? current + 1 : 0
        longest = max(longest, current)
    }
    return longest
}

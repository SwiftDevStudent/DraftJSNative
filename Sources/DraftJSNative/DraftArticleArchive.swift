import Foundation

/// Preserves every JSON field in an Article result while exposing the fields
/// understood by DraftJSNative. Unknown fields remain in the exported JSON.
public struct DraftArticleArchive {
    public let article: DraftArticlePayload
    private let source: JSONValue

    public init(jsonData: Data) throws {
        article = try DraftArticlePayload(jsonData: jsonData)
        source = try JSONDecoder().decode(JSONValue.self, from: jsonData)
    }

    /// Serializes the original Article result with the same JSON values and
    /// structure. Object key order and whitespace may differ.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(source)
    }

    public func replacingTitle(with title: String) throws -> DraftArticleArchive {
        guard case .object(var articleJSON) = source else {
            throw DraftArticleEditError.invalidArchive
        }
        articleJSON["title"] = .string(title)
        return try Self(jsonData: Self.encode(.object(articleJSON)))
    }

    /// Replaces text within one non-atomic block. Offsets and lengths use
    /// UTF-16 code units, as in Draft.js. Inserted text receives only the
    /// explicitly supplied styles; edits intersecting entities are rejected.
    public func replacingText(
        inBlock key: String,
        range: NSRange,
        with replacement: String,
        styles: [String] = []
    ) throws -> DraftArticleArchive {
        guard !replacement.contains("\n"), !replacement.contains("\r") else {
            throw DraftArticleEditError.multilineReplacement
        }
        let matchingBlocks = article.document.blocks.filter { $0.key == key }
        guard !matchingBlocks.isEmpty else { throw DraftArticleEditError.blockNotFound(key) }
        guard matchingBlocks.count == 1 else { throw DraftArticleEditError.ambiguousBlockKey(key) }
        let block = matchingBlocks[0]
        guard block.type != "atomic" else { throw DraftArticleEditError.atomicBlock(key) }
        let textLength = block.text.utf16.count
        guard range.location >= 0, range.length >= 0,
              range.location <= textLength,
              range.length <= textLength - range.location,
              let stringRange = Range(range, in: block.text) else {
            throw DraftArticleEditError.invalidRange(key)
        }
        let start = range.location
        let end = start + range.length
        for entity in block.entityRanges {
            let entityEnd = entity.offset + entity.length
            let intersects = start == end
                ? entity.offset < start && start < entityEnd
                : entity.offset < end && start < entityEnd
            if intersects { throw DraftArticleEditError.entityIntersection(key) }
        }

        guard case .object(var articleJSON) = source,
              case .object(var contentJSON)? = articleJSON["content_state"],
              case .array(var blocksJSON)? = contentJSON["blocks"] else {
            throw DraftArticleEditError.invalidArchive
        }
        let index = article.document.blocks.firstIndex { $0.key == key }!
        guard case .object(var blockJSON) = blocksJSON[index] else {
            throw DraftArticleEditError.invalidArchive
        }
        blockJSON["text"] = .string(block.text.replacingCharacters(in: stringRange, with: replacement))
        let delta = replacement.utf16.count - range.length

        let styleKey = blockJSON["inlineStyleRanges"] != nil ? "inlineStyleRanges" : "inline_style_ranges"
        var styleRanges = try adjustedRanges(
            blockJSON[styleKey], start: start, end: end, delta: delta,
            rejectOverlap: false, blockKey: key
        )
        if !replacement.isEmpty {
            for style in Set(styles).sorted() {
                styleRanges.append(.object([
                    "offset": .number(Decimal(start)),
                    "length": .number(Decimal(replacement.utf16.count)),
                    "style": .string(style),
                ]))
            }
        }
        styleRanges.sort { Self.rangeOffset($0) < Self.rangeOffset($1) }
        blockJSON[styleKey] = .array(styleRanges)

        let entityKey = blockJSON["entityRanges"] != nil ? "entityRanges" : "entity_ranges"
        if blockJSON[entityKey] != nil {
            blockJSON[entityKey] = .array(try adjustedRanges(
                blockJSON[entityKey], start: start, end: end, delta: delta,
                rejectOverlap: true, blockKey: key
            ))
        }
        blocksJSON[index] = .object(blockJSON)
        contentJSON["blocks"] = .array(blocksJSON)
        articleJSON["content_state"] = .object(contentJSON)
        return try Self(jsonData: Self.encode(.object(articleJSON)))
    }

    private static func encode(_ value: JSONValue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func rangeOffset(_ value: JSONValue) -> Int {
        guard case .object(let object) = value,
              case .number(let offset)? = object["offset"] else { return 0 }
        return Int(NSDecimalNumber(decimal: offset).stringValue) ?? 0
    }

    private func adjustedRanges(
        _ value: JSONValue?, start: Int, end: Int, delta: Int,
        rejectOverlap: Bool, blockKey: String
    ) throws -> [JSONValue] {
        guard let value else { return [] }
        guard case .array(let ranges) = value else { throw DraftArticleEditError.invalidArchive }
        var adjusted: [JSONValue] = []
        for range in ranges {
            guard case .object(let object) = range,
                  case .number(let offset)? = object["offset"],
                  case .number(let length)? = object["length"],
                  let originalStart = Int(NSDecimalNumber(decimal: offset).stringValue),
                  let originalLength = Int(NSDecimalNumber(decimal: length).stringValue) else {
                throw DraftArticleEditError.invalidArchive
            }
            let originalEnd = originalStart + originalLength
            if originalEnd <= start {
                adjusted.append(range)
            } else if originalStart >= end {
                var shifted = object
                shifted["offset"] = .number(Decimal(originalStart + delta))
                adjusted.append(.object(shifted))
            } else if rejectOverlap {
                throw DraftArticleEditError.entityIntersection(blockKey)
            } else {
                if originalStart < start {
                    var prefix = object
                    prefix["length"] = .number(Decimal(start - originalStart))
                    adjusted.append(.object(prefix))
                }
                if originalEnd > end {
                    var suffix = object
                    suffix["offset"] = .number(Decimal(end + delta))
                    suffix["length"] = .number(Decimal(originalEnd - end))
                    adjusted.append(.object(suffix))
                }
            }
        }
        return adjusted
    }
}

public enum DraftArticleEditError: Error, Equatable {
    case blockNotFound(String)
    case ambiguousBlockKey(String)
    case invalidRange(String)
    case atomicBlock(String)
    case entityIntersection(String)
    case multilineReplacement
    case invalidArchive
}

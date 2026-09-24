import Foundation

/// A decoded Draft.js raw content state. `blocks` remain in source order.
public struct DraftDocument: Decodable {
    public let blocks: [DraftBlock]
    public let entities: [String: DraftEntity]

    public init(jsonData: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: jsonData)
    }

    private enum CodingKeys: String, CodingKey {
        case blocks, entityMap, entity_map, entities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blocks = try container.decode([DraftBlock].self, forKey: .blocks)
        if container.contains(.entityMap) {
            entities = try Self.decodeEntities(container, key: .entityMap)
        } else if container.contains(.entity_map) {
            entities = try Self.decodeEntities(container, key: .entity_map)
        } else if container.contains(.entities) {
            entities = try Self.decodeEntities(container, key: .entities)
        } else {
            entities = [:]
        }
        for block in blocks {
            try Self.validate(block, entities: entities)
        }
    }

    private static func decodeEntities(
        _ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys
    ) throws -> [String: DraftEntity] {
        if let map = try? container.decode([String: DraftEntity].self, forKey: key) {
            return map
        }
        let entries = try container.decode([EntityEntry].self, forKey: key)
        var result: [String: DraftEntity] = [:]
        for entry in entries {
            guard result.updateValue(entry.value, forKey: entry.key) == nil else {
                throw DraftParseError.duplicateEntity(entry.key)
            }
        }
        return result
    }

    private static func validate(_ block: DraftBlock, entities: [String: DraftEntity]) throws {
        for range in block.inlineStyleRanges {
            try validateRange(range.offset, range.length, in: block)
        }
        for range in block.entityRanges {
            try validateRange(range.offset, range.length, in: block)
            guard entities[range.key] != nil else {
                throw DraftParseError.missingEntity(block: block.key, key: range.key)
            }
        }
        let entityRanges = block.entityRanges.filter { $0.length > 0 }
        for firstIndex in entityRanges.indices {
            for secondIndex in entityRanges.indices where secondIndex > firstIndex {
                let first = entityRanges[firstIndex]
                let second = entityRanges[secondIndex]
                if first.key != second.key && first.offset < second.offset + second.length
                    && second.offset < first.offset + first.length {
                    throw DraftParseError.overlappingEntities(block: block.key)
                }
            }
        }
    }

    private static func validateRange(_ offset: Int, _ length: Int, in block: DraftBlock) throws {
        let units = Array(block.text.utf16)
        let utf16Length = units.count
        guard offset >= 0, length >= 0, offset <= utf16Length,
              length <= utf16Length - offset,
              isScalarBoundary(offset, in: units),
              isScalarBoundary(offset + length, in: units),
              Range(NSRange(location: offset, length: length), in: block.text) != nil else {
            throw DraftParseError.invalidRange(block: block.key, offset: offset, length: length)
        }
    }

    private static func isScalarBoundary(_ offset: Int, in units: [UInt16]) -> Bool {
        guard offset > 0, offset < units.count else { return true }
        let previous = units[offset - 1]
        let next = units[offset]
        return !(0xD800...0xDBFF).contains(previous) || !(0xDC00...0xDFFF).contains(next)
    }

    /// Splits a block at style and entity boundaries for native rendering.
    public func runs(in block: DraftBlock) -> [DraftRun] {
        let end = block.text.utf16.count
        guard end > 0 else { return [] }
        var boundaries: Set<Int> = [0, end]
        for range in block.inlineStyleRanges {
            boundaries.insert(range.offset)
            boundaries.insert(range.offset + range.length)
        }
        for range in block.entityRanges {
            boundaries.insert(range.offset)
            boundaries.insert(range.offset + range.length)
        }
        let cuts = boundaries.sorted()
        return zip(cuts, cuts.dropFirst()).compactMap { start, stop in
            guard start < stop,
                  let substringRange = Range(NSRange(location: start, length: stop - start),
                                             in: block.text) else { return nil }
            let styles = block.inlineStyleRanges.filter {
                $0.length > 0 && $0.offset <= start && start < $0.offset + $0.length
            }.map(\.style)
            let entityKey = block.entityRanges.first {
                $0.length > 0 && $0.offset <= start && start < $0.offset + $0.length
            }?.key
            return DraftRun(
                text: String(block.text[substringRange]),
                styles: styles,
                entity: entityKey.flatMap { entities[$0] }
            )
        }
    }
}

public enum DraftParseError: Error, Equatable {
    case invalidRange(block: String, offset: Int, length: Int)
    case missingEntity(block: String, key: String)
    case overlappingEntities(block: String)
    case duplicateEntity(String)
}

public struct DraftBlock: Decodable {
    public let key: String
    public let type: String
    public let text: String
    public let depth: Int
    public let data: [String: JSONValue]
    public let inlineStyleRanges: [DraftStyleRange]
    public let entityRanges: [DraftEntityRange]

    private enum CodingKeys: String, CodingKey {
        case key, type, text, depth, data
        case inlineStyleRanges, inline_style_ranges
        case entityRanges, entity_ranges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
        type = try container.decode(String.self, forKey: .type)
        text = try container.decode(String.self, forKey: .text)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        data = try container.decodeIfPresent([String: JSONValue].self, forKey: .data) ?? [:]
        inlineStyleRanges = try container.decodeIfPresent([DraftStyleRange].self,
                                                           forKey: .inlineStyleRanges)
            ?? container.decodeIfPresent([DraftStyleRange].self, forKey: .inline_style_ranges)
            ?? []
        entityRanges = try container.decodeIfPresent([DraftEntityRange].self, forKey: .entityRanges)
            ?? container.decodeIfPresent([DraftEntityRange].self, forKey: .entity_ranges)
            ?? []
    }
}

public struct DraftStyleRange: Decodable {
    public let offset: Int
    public let length: Int
    public let style: String
}

public struct DraftEntityRange: Decodable {
    public let offset: Int
    public let length: Int
    public let key: String

    private enum CodingKeys: CodingKey { case offset, length, key }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offset = try container.decode(Int.self, forKey: .offset)
        length = try container.decode(Int.self, forKey: .length)
        key = try container.decode(StringOrInt.self, forKey: .key).value
    }
}

public struct DraftEntity: Decodable {
    public let type: String
    public let mutability: String?
    public let data: [String: JSONValue]

    private enum CodingKeys: CodingKey { case type, mutability, data }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        mutability = try container.decodeIfPresent(String.self, forKey: .mutability)
        data = try container.decodeIfPresent([String: JSONValue].self, forKey: .data) ?? [:]
    }
}

public struct DraftRun {
    public let text: String
    public let styles: [String]
    public let entity: DraftEntity?
}

private struct EntityEntry: Decodable {
    let key: String
    let value: DraftEntity

    private enum CodingKeys: CodingKey { case key, value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(StringOrInt.self, forKey: .key).value
        value = try container.decode(DraftEntity.self, forKey: .value)
    }
}

private enum StringOrInt: Decodable {
    case string(String)
    case int(Int)

    var value: String {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) { self = .int(value) }
        else { self = .string(try container.decode(String.self)) }
    }
}

/// Keeps app-specific entity and block metadata available to native consumers.
public enum JSONValue: Decodable, Equatable {
    case string(String), number(Decimal), bool(Bool), object([String: JSONValue])
    case array([JSONValue]), null

    public var stringValue: String? {
        if case .string(let value) = self { value } else { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Decimal.self) { self = .number(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }
}

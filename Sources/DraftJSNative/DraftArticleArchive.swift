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
}

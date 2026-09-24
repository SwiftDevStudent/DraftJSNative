import Foundation

/// An Article result with its Draft.js body and companion media metadata.
/// Decode the Article result itself; a host app extracts it from its network response.
public struct DraftArticlePayload: Decodable {
    public let title: String
    public let document: DraftDocument
    public let coverMedia: DraftArticleMedia?
    public let mediaEntities: [DraftArticleMedia]

    private enum CodingKeys: String, CodingKey {
        case title, content_state, cover_media, media_entities
    }

    public init(jsonData: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: jsonData)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        document = try container.decode(DraftDocument.self, forKey: .content_state)
        coverMedia = try container.decodeIfPresent(DraftArticleMedia.self, forKey: .cover_media)
        mediaEntities = try container.decodeIfPresent([DraftArticleMedia].self, forKey: .media_entities) ?? []
    }

    public func imageURL(forMediaID id: String) -> URL? {
        mediaEntities.first { $0.mediaID == id }?.imageURL
    }
}

public struct DraftArticleMedia: Decodable {
    public let mediaID: String
    public let mediaInfo: [String: JSONValue]

    private enum CodingKeys: String, CodingKey { case media_id, media_info }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mediaID = try container.decode(String.self, forKey: .media_id)
        mediaInfo = try container.decodeIfPresent([String: JSONValue].self, forKey: .media_info) ?? [:]
    }

    public var imageURL: URL? {
        guard let raw = mediaInfo["original_img_url"]?.stringValue,
              let url = URL(string: raw),
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
}

/// A media reference in a Draft.js MEDIA entity. The Article's media metadata
/// supplies the URL separately from this reference.
public struct DraftMediaItem {
    public let mediaID: String
    public let category: String?
    public let data: [String: JSONValue]
}

extension DraftEntity {
    public var mediaItems: [DraftMediaItem] {
        let value = data["mediaItems"] ?? data["media_items"]
        guard case .array(let values) = value else { return [] }
        return values.compactMap { value in
            guard case .object(let item) = value,
                  let id = item["mediaId"]?.stringValue ?? item["media_id"]?.stringValue else {
                return nil
            }
            return DraftMediaItem(
                mediaID: id,
                category: item["mediaCategory"]?.stringValue ?? item["media_category"]?.stringValue,
                data: item
            )
        }
    }
}

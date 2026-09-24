import Foundation
import XCTest
@testable import DraftJSNative

final class DraftArticlePayloadTests: XCTestCase {
    func testArticleArchivePreservesUnknownFieldsAndLargeIDs() throws {
        let source = Data(#"""
        {
          "title":"שלום 😀 Article",
          "content_state":{
            "blocks":[{"key":"one","type":"unstyled","text":"Hi 👨‍👩‍👧‍👦 שלום",
              "depth":0,"data":{"custom":{"large":2073636721275641856}},
              "inlineStyleRanges":[{"offset":3,"length":11,"style":"BOLD"}],
              "entityRanges":[],"unknown_block_field":[true,null,"kept"]}],
            "entityMap":{},"unknown_content_field":{"version":3}
          },
          "cover_media":null,
          "unknown_article_field":{"nested":[1,2,{"exact":"value"}]}
        }
        """#.utf8)
        let archive = try DraftArticleArchive(jsonData: source)
        let output = try archive.jsonData()

        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: output),
                       try JSONDecoder().decode(JSONValue.self, from: source))
        XCTAssertEqual(try DraftArticlePayload(jsonData: output).document.blocks[0].text,
                       "Hi 👨‍👩‍👧‍👦 שלום")
    }

    func testArticleEnvelopeResolvesAllGalleryItems() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sample = packageRoot.appendingPathComponent("Examples/sample-article-envelope.json")
        let article = try DraftArticlePayload(jsonData: Data(contentsOf: sample))

        XCTAssertEqual(article.document.blocks.count, 21)
        let gallery = article.document.blocks.first { $0.key == "gallery" }!
        let entity = article.document.entities[gallery.entityRanges[0].key]!
        XCTAssertEqual(entity.mediaItems.map(\.mediaID), ["demo-a", "demo-b"])
        XCTAssertEqual(article.imageURL(forMediaID: "demo-b")?.absoluteString,
                       "https://example.com/b.png")

        let markdown = article.document.markdown { article.imageURL(forMediaID: $0) }
        XCTAssertTrue(markdown.text.contains("![Media 1](<https://example.com/a.png>)\n"
                                          + "![Media 2](<https://example.com/b.png>)"))
        XCTAssertTrue(markdown.text.contains("Two views of the same story"))
        XCTAssertTrue(markdown.text.contains("https://x.com/i/status/1234567890123456789"))
        XCTAssertEqual(markdown.warnings.filter { $0.contains("native tweet_video playback") }.count, 1)
        XCTAssertTrue(markdown.warnings.contains("Unsupported atomic entity LATEX in block latex"))
        XCTAssertEqual(article.document.defaultRendererWarnings(mediaURLForID: { article.imageURL(forMediaID: $0) }), [
            "Block post needs a native embedded post component",
            "Media demo-video needs native playback from the host",
            "Block latex needs a native LATEX renderer",
        ])
        XCTAssertEqual(article.document.defaultRendererWarnings(
            mediaURLForID: { article.imageURL(forMediaID: $0) },
            playbackURLForID: { $0 == "demo-video" ? URL(string: "https://example.com/video.mp4") : nil }
        ), [
            "Block post needs a native embedded post component",
            "Block latex needs a native LATEX renderer",
        ])
    }

    func testMalformedArticleEnvelopeDoesNotFallBackToRawDocument() {
        XCTAssertThrowsError(try DraftArticlePayload(jsonData: Data(#"{"title":"Broken","content_state":{}}"#.utf8)))
    }
}

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

    func testArticleEditShiftsUTF16RangesWithoutLosingUnknownFields() throws {
        let source = Data(#"""
        {"title":"Original","unknown_article":{"large":2073636721275641856},
         "content_state":{"blocks":[
           {"key":"body","type":"unstyled","text":"A😀BC שלום","depth":0,
            "data":{"unknown":"kept"},"unknown_block":true,
            "inlineStyleRanges":[{"offset":0,"length":5,"style":"BOLD","extra":7}],
            "entityRanges":[{"offset":6,"length":4,"key":0}]}],
          "entityMap":{"0":{"type":"LINK","mutability":"MUTABLE",
                           "data":{"url":"https://example.com"}}}}}
        """#.utf8)
        let archive = try DraftArticleArchive(jsonData: source)
        let edited = try archive.replacingText(
            inBlock: "body", range: NSRange(location: 1, length: 2),
            with: "👨‍👩‍👧‍👦", styles: ["BOLD"]
        ).replacingTitle(with: "Edited")
        let output = try edited.jsonData()
        let article = try DraftArticlePayload(jsonData: output)

        XCTAssertEqual(article.title, "Edited")
        XCTAssertEqual(article.document.blocks[0].text, "A👨‍👩‍👧‍👦BC שלום")
        XCTAssertEqual(article.document.blocks[0].entityRanges[0].offset, 15)
        XCTAssertEqual(article.document.runs(in: article.document.blocks[0])
            .first { $0.entity?.type == "LINK" }?.text, "שלום")
        XCTAssertEqual(article.document.runs(in: article.document.blocks[0])
            .first { $0.text == "👨‍👩‍👧‍👦" }?.styles, ["BOLD"])
        let root = try JSONDecoder().decode(JSONValue.self, from: output)
        guard case .object(let rootObject) = root,
              case .object(let content)? = rootObject["content_state"],
              case .array(let blocks)? = content["blocks"],
              case .object(let block) = blocks[0] else {
            return XCTFail("Missing edited Article fields")
        }
        XCTAssertEqual(rootObject["unknown_article"],
                       .object(["large": .number(Decimal(string: "2073636721275641856")!)]))
        XCTAssertEqual(block["unknown_block"], .bool(true))
        XCTAssertEqual(block["data"], .object(["unknown": .string("kept")]))
        guard case .array(let styles)? = block["inlineStyleRanges"] else {
            return XCTFail("Missing edited style ranges")
        }
        XCTAssertEqual(styles.compactMap { value -> Decimal? in
            guard case .object(let object) = value,
                  case .number(let offset)? = object["offset"] else { return nil }
            return offset
        }, [0, 1, 12])
    }

    func testArticleEditRefusesEntityAndAtomicTextChanges() throws {
        let source = Data(#"""
        {"title":"Original","content_state":{"blocks":[
          {"key":"link","type":"unstyled","text":"Hello","entityRanges":[{"offset":0,"length":5,"key":0}]},
          {"key":"media","type":"atomic","text":" ","entityRanges":[{"offset":0,"length":1,"key":1}]}
        ],"entityMap":{"0":{"type":"LINK","data":{"url":"https://example.com"}},
                       "1":{"type":"DIVIDER","data":{}}}}}
        """#.utf8)
        let archive = try DraftArticleArchive(jsonData: source)
        XCTAssertThrowsError(try archive.replacingText(
            inBlock: "link", range: NSRange(location: 2, length: 1), with: "X"
        )) { error in
            XCTAssertEqual(error as? DraftArticleEditError, .entityIntersection("link"))
        }
        XCTAssertThrowsError(try archive.replacingText(
            inBlock: "media", range: NSRange(location: 0, length: 1), with: "X"
        )) { error in
            XCTAssertEqual(error as? DraftArticleEditError, .atomicBlock("media"))
        }
        XCTAssertThrowsError(try archive.replacingText(
            inBlock: "link", range: NSRange(location: 0, length: 0), with: "New\nline"
        )) { error in
            XCTAssertEqual(error as? DraftArticleEditError, .multilineReplacement)
        }
        XCTAssertEqual(try archive.jsonData(), try DraftArticleArchive(jsonData: source).jsonData())
    }

    func testArticleEditKeepsXSnakeCaseFields() throws {
        let source = Data(#"""
        {"title":"עברית","content_state":{"blocks":[
          {"key":"body","type":"unstyled","text":"שלום 😀",
           "inline_style_ranges":[],"entity_ranges":[],"data":{"locale":"he"}}],
          "entity_map":[]}}
        """#.utf8)
        let edited = try DraftArticleArchive(jsonData: source).replacingText(
            inBlock: "body", range: NSRange(location: 5, length: 2),
            with: "🚀", styles: ["BOLD"]
        )
        let output = try edited.jsonData()
        guard case .object(let root) = try JSONDecoder().decode(JSONValue.self, from: output),
              case .object(let content)? = root["content_state"],
              case .array(let blocks)? = content["blocks"],
              case .object(let block) = blocks[0] else {
            return XCTFail("Missing edited Article fields")
        }
        XCTAssertNotNil(block["inline_style_ranges"])
        XCTAssertNil(block["inlineStyleRanges"])
        XCTAssertEqual(block["text"], .string("שלום 🚀"))
        XCTAssertEqual(block["data"], .object(["locale": .string("he")]))
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

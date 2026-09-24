import Foundation
import XCTest
@testable import DraftJSNative

final class DraftDocumentTests: XCTestCase {
    func testOfficialXArticlesEntityFieldAndOptionalBlockKey() throws {
        let document = try parse(#"""
        {"blocks":[{"type":"unstyled","text":"Hello from X",
          "entity_ranges":[{"offset":6,"length":4,"key":0}]}],
          "entities":[{"key":"0","value":{"type":"LINK","data":{"url":"https://x.com"}}}]}
        """#)
        XCTAssertEqual(document.blocks[0].key, "")
        XCTAssertEqual(document.runs(in: document.blocks[0]).first { $0.entity != nil }?.text,
                       "from")
        XCTAssertEqual(document.markdown().text, "Hello [from](<https://x.com>) X")
    }

    func testBilingualSampleKeepsEmojiAndHebrewRanges() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sample = packageRoot.appendingPathComponent("Examples/sample-article.json")
        let document = try DraftDocument(jsonData: Data(contentsOf: sample))

        let body = document.blocks.first { $0.key == "body" }!
        let bodyRuns = document.runs(in: body)
        XCTAssertEqual(bodyRuns.first { $0.styles.contains("Bold") }?.text, "שלום 👋🏽 עולם")
        XCTAssertEqual(bodyRuns.first { $0.styles.contains("Italic") }?.text,
                       "עברית 😀🚀🇮🇱🧑🏽‍💻")
        XCTAssertEqual(bodyRuns.first { $0.entity?.type == "LINK" }?.text, "Swift")

        let parade = document.blocks.first { $0.key == "parade" }!
        let paradeRuns = document.runs(in: parade)
        XCTAssertEqual(paradeRuns.first { $0.styles.contains("Bold") }?.text,
                       "👨‍👩‍👧‍👦 🏳️‍🌈")
        XCTAssertEqual(paradeRuns.first { $0.entity?.type == "LINK" }?.text, "בוקר טוב")
    }

    func testCanonicalDraftJSUsesUTF16RangesAndRendersLink() throws {
        let document = try parse(#"""
        {
          "blocks": [{
            "key": "one", "type": "unstyled", "text": "Hi 😀 world", "depth": 0,
            "inlineStyleRanges": [{"offset": 3, "length": 2, "style": "BOLD"}],
            "entityRanges": [{"offset": 6, "length": 5, "key": 0}], "data": {}
          }],
          "entityMap": {"0": {"type": "LINK", "mutability": "MUTABLE",
            "data": {"url": "https://example.com"}}}
        }
        """#)

        let runs = document.runs(in: document.blocks[0])
        XCTAssertEqual(runs.map(\.text), ["Hi ", "😀", " ", "world"])
        XCTAssertEqual(runs[1].styles, ["BOLD"])
        XCTAssertEqual(runs[3].entity?.type, "LINK")
        XCTAssertEqual(document.markdown().text, "Hi **😀** [world](<https://example.com>)")
    }

    func testXArticleSnakeCaseArrayAndAtomicEntities() throws {
        let document = try parse(#"""
        {
          "blocks": [
            {"key":"heading","type":"header-one","text":"Article","inline_style_ranges":[],"entity_ranges":[]},
            {"key":"code","type":"atomic","text":" ","inline_style_ranges":[],"entity_ranges":[{"offset":0,"length":1,"key":1}]},
            {"key":"image","type":"atomic","text":" ","inline_style_ranges":[],"entity_ranges":[{"offset":0,"length":1,"key":2}]},
            {"key":"rule","type":"atomic","text":" ","inline_style_ranges":[],"entity_ranges":[{"offset":0,"length":1,"key":3}]}
          ],
          "entity_map": [
            {"key":1,"value":{"type":"MARKDOWN","mutability":"Mutable","data":{"markdown":"\n```swift\nprint(1)\n```\n"}}},
            {"key":2,"value":{"type":"MEDIA","mutability":"Immutable","data":{"media_items":[{"media_id":"42"}]}}},
            {"key":3,"value":{"type":"DIVIDER","mutability":"Immutable","data":{}}}
          ]
        }
        """#)

        let unresolved = document.markdown()
        XCTAssertTrue(unresolved.text.contains("[Media: 42]"))
        XCTAssertEqual(unresolved.warnings, ["Media 42 needs a URL from article metadata"])

        let resolved = document.markdown { $0 == "42" ? URL(string: "https://example.com/a.png") : nil }
        XCTAssertEqual(resolved.text,
                       "# Article\n\n```swift\nprint(1)\n```\n\n![Media](<https://example.com/a.png>)\n\n---")
        XCTAssertTrue(resolved.warnings.isEmpty)
    }

    func testXArticleEmbeddedPostUsesDocumentedPostID() throws {
        let document = try parse(#"""
        {"blocks":[{"key":"post","type":"atomic","text":" ",
          "entity_ranges":[{"offset":0,"length":1,"key":0}]}],
          "entities":[{"key":0,"value":{"type":"TWEET",
            "data":{"post_id":"1234567890123456789"}}}]}
        """#)
        let result = document.markdown()
        XCTAssertEqual(result.text, "https://x.com/i/status/1234567890123456789")
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testConsecutiveListItemsStayInOneMarkdownList() throws {
        let document = try parse(#"""
        {"blocks":[
          {"key":"a","type":"unordered-list-item","text":"First"},
          {"key":"b","type":"unordered-list-item","text":"Child","depth":1},
          {"key":"c","type":"unordered-list-item","text":"Second"},
          {"key":"d","type":"unstyled","text":"After"}
        ],"entityMap":{}}
        """#)
        XCTAssertEqual(document.markdown().text, "- First\n  - Child\n- Second\n\nAfter")
    }

    func testXArticleCamelCaseArrayContentState() throws {
        let document = try parse(#"""
        {"blocks":[
          {"key":"intro","type":"unstyled","text":"שלום 😀 Swift",
            "inlineStyleRanges":[{"offset":0,"length":7,"style":"BOLD"}],
            "entityRanges":[{"offset":8,"length":5,"key":0}]},
          {"key":"code","type":"atomic","text":" ",
            "entityRanges":[{"offset":0,"length":1,"key":1}]},
          {"key":"image","type":"atomic","text":" ",
            "entityRanges":[{"offset":0,"length":1,"key":2}]}
        ],"entityMap":[
          {"key":0,"value":{"type":"LINK","data":{"url":"https://swift.org"}}},
          {"key":1,"value":{"type":"MARKDOWN","data":{"markdown":"\n```swift\nprint(1)\n```\n"}}},
          {"key":2,"value":{"type":"MEDIA","data":{"media_items":[{"media_id":"synthetic-image"}]}}}
        ]}
        """#)

        XCTAssertEqual(document.blocks.count, 3)
        XCTAssertEqual(document.entities.count, 3)
        let markdown = document.markdown { mediaID in
            mediaID == "synthetic-image" ? URL(string: "https://example.com/image.png") : nil
        }
        XCTAssertTrue(markdown.warnings.isEmpty)
        XCTAssertTrue(markdown.text.contains("[Swift](<https://swift.org>)"))
        XCTAssertTrue(markdown.text.contains("```swift\nprint(1)\n```"))
        XCTAssertTrue(markdown.text.contains("![Media](<https://example.com/image.png>)"))
    }

    func testOverlappingStylesCreateSemanticRuns() throws {
        let document = try parse(#"""
        {"blocks":[{"key":"b","type":"unstyled","text":"abcdef",
          "inlineStyleRanges":[{"offset":0,"length":4,"style":"BOLD"},{"offset":2,"length":4,"style":"ITALIC"}],
          "entityRanges":[]}],"entityMap":{}}
        """#)
        let runs = document.runs(in: document.blocks[0])
        XCTAssertEqual(runs.map(\.text), ["ab", "cd", "ef"])
        XCTAssertEqual(runs.map(\.styles), [["BOLD"], ["BOLD", "ITALIC"], ["ITALIC"]])
        XCTAssertEqual(document.markdown().text,
                       "<strong>ab</strong><em><strong>cd</strong></em><em>ef</em>")
        XCTAssertEqual(document.markdown().warnings, ["Overlapping styles use inline HTML in block b"])
    }

    func testUnderlineRendersWithoutBeingReportedUnsupported() throws {
        let document = try parse(#"""
        {"blocks":[{"key":"underlined","type":"unstyled","text":"שלום 😀",
          "inlineStyleRanges":[{"offset":0,"length":7,"style":"UNDERLINE"}]}],
         "entityMap":{}}
        """#)
        XCTAssertEqual(document.runs(in: document.blocks[0]).first?.styles, ["UNDERLINE"])
        XCTAssertEqual(document.markdown().text, "<u>שלום 😀</u>")
        XCTAssertEqual(document.markdown().warnings,
                       ["Underline uses inline HTML in block underlined"])
        XCTAssertTrue(document.defaultRendererWarnings().isEmpty)
    }

    func testInvalidSurrogateBoundaryIsRejected() {
        XCTAssertThrowsError(try parse(#"""
        {"blocks":[{"key":"b","type":"unstyled","text":"😀",
          "inlineStyleRanges":[{"offset":1,"length":1,"style":"BOLD"}],"entityRanges":[]}],
          "entityMap":{}}
        """#)) { error in
            XCTAssertEqual(error as? DraftParseError, .invalidRange(block: "b", offset: 1, length: 1))
        }
    }

    func testMissingEntityAndOverlapAreRejected() {
        XCTAssertThrowsError(try parse(#"""
        {"blocks":[{"key":"b","type":"unstyled","text":"abc","inlineStyleRanges":[],
          "entityRanges":[{"offset":0,"length":1,"key":9}]}],"entityMap":{}}
        """#)) { error in
            XCTAssertEqual(error as? DraftParseError, .missingEntity(block: "b", key: "9"))
        }

        XCTAssertThrowsError(try parse(#"""
        {"blocks":[{"key":"b","type":"unstyled","text":"abc","inlineStyleRanges":[],
          "entityRanges":[{"offset":0,"length":2,"key":1},{"offset":1,"length":2,"key":2}]}],
          "entityMap":{"1":{"type":"LINK"},"2":{"type":"LINK"}}}
        """#)) { error in
            XCTAssertEqual(error as? DraftParseError, .overlappingEntities(block: "b"))
        }
    }

    func testUnknownContentIsPreservedAndReported() throws {
        let document = try parse(#"""
        {"blocks":[{"key":"b","type":"custom-card","text":"Hello","data":{"id":"card-1","large":2073636721275641856},
          "inlineStyleRanges":[],"entityRanges":[]}],"entityMap":{}}
        """#)
        XCTAssertEqual(document.blocks[0].data["id"], .string("card-1"))
        XCTAssertEqual(document.blocks[0].data["large"], .number(Decimal(string: "2073636721275641856")!))
        XCTAssertEqual(document.markdown().text, "Hello")
        XCTAssertEqual(document.markdown().warnings, ["Unsupported block type custom-card in block b"])
    }

    private func parse(_ json: String) throws -> DraftDocument {
        try DraftDocument(jsonData: Data(json.utf8))
    }
}

import XCTest
@testable import DraftJSNative

final class DraftMarkdownTableTests: XCTestCase {
    func testParsesBilingualTableAndEscapedPipe() throws {
        let table = try XCTUnwrap(DraftMarkdownTable(markdown: """
        | Language | Text |
        |---|---|
        | עברית | שלום 👋🏽 |
        | English | one \\| two |
        """))
        XCTAssertEqual(table.rows, [
            ["Language", "Text"],
            ["עברית", "שלום 👋🏽"],
            ["English", "one | two"],
        ])
    }

    func testDoesNotTreatOrdinaryMarkdownAsTable() {
        XCTAssertNil(DraftMarkdownTable(markdown: "A paragraph with | a pipe"))
        XCTAssertNil(DraftMarkdownTable(markdown: "| One | Two |\n|---|\n| A | B |"))
    }
}

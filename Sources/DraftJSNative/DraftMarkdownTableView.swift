import Foundation
import SwiftUI

struct DraftMarkdownTable {
    let rows: [[String]]

    init?(markdown: String) {
        let lines = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        guard lines.count >= 2,
              let header = Self.cells(in: lines[0]),
              let separator = Self.cells(in: lines[1]),
              !header.isEmpty, separator.count == header.count,
              separator.allSatisfy({ $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil })
        else { return nil }

        var parsed = [header]
        for line in lines.dropFirst(2) {
            guard let cells = Self.cells(in: line), cells.count == header.count else { return nil }
            parsed.append(cells)
        }
        rows = parsed
    }

    private static func cells(in line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return nil }
        let content = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        var cells: [String] = []
        var current = ""
        var escaped = false
        for character in content {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        if escaped { current.append("\\") }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }
}

struct DraftMarkdownTableView: View {
    let table: DraftMarkdownTable

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                ForEach(table.rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(table.rows[row].indices, id: \.self) { column in
                            Text((try? AttributedString(markdown: table.rows[row][column]))
                                 ?? AttributedString(table.rows[row][column]))
                                .font(row == 0 ? .headline : .body)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    if row == 0 { Divider() }
                }
            }
            .padding(12)
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

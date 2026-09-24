import SwiftUI

/// A native, read-only Article body. The caller supplies the title and Draft.js content_state.
/// `atomicViewForEntity` lets the host render post and media entities with its native components.
public struct DraftArticleView: View {
    public let title: String
    public let document: DraftDocument
    public let coverURL: URL?
    public let mediaURLForID: (String) -> URL?
    public let playbackURLForID: (String) -> URL?
    public let atomicViewForEntity: (DraftEntity) -> AnyView?

    public init(
        title: String,
        document: DraftDocument,
        coverURL: URL? = nil,
        mediaURLForID: @escaping (String) -> URL? = { _ in nil },
        playbackURLForID: @escaping (String) -> URL? = { _ in nil },
        atomicViewForEntity: @escaping (DraftEntity) -> AnyView? = { _ in nil }
    ) {
        self.title = title
        self.document = document
        self.coverURL = coverURL
        self.mediaURLForID = mediaURLForID
        self.playbackURLForID = playbackURLForID
        self.atomicViewForEntity = atomicViewForEntity
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverURL {
                AsyncImage(url: coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: 600)
                .frame(height: 240)
                .clipped()
                .padding(.bottom, 24)
            }
            Text(title)
                .font(.system(size: 36, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 27)

            ForEach(document.blocks.indices, id: \.self) { index in
                DraftArticleBlockView(
                    document: document,
                    block: document.blocks[index],
                    orderedNumber: orderedNumber(at: index),
                    mediaURLForID: mediaURLForID,
                    playbackURLForID: playbackURLForID,
                    atomicViewForEntity: atomicViewForEntity
                )
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: 600, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }

    private func orderedNumber(at index: Int) -> Int {
        let depth = document.blocks[index].depth
        var count = 0
        for block in document.blocks[...index].reversed() {
            guard block.type == "ordered-list-item" else { break }
            if block.depth == depth { count += 1 }
        }
        return count
    }
}

private struct DraftArticleBlockView: View {
    let document: DraftDocument
    let block: DraftBlock
    let orderedNumber: Int
    let mediaURLForID: (String) -> URL?
    let playbackURLForID: (String) -> URL?
    let atomicViewForEntity: (DraftEntity) -> AnyView?

    var body: some View {
        Group {
            switch block.type {
            case "header-one", "header-two", "header-three", "header-four", "header-five", "header-six":
                richText
                    .font(.system(size: headingSize, weight: .bold))
            case "blockquote":
                richText
                    .padding(.leading, 19)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.secondary).frame(width: 3)
                    }
            case "unordered-list-item", "ordered-list-item":
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(block.type == "unordered-list-item" ? "•" : "\(orderedNumber).")
                    richText
                }
                .padding(.leading, CGFloat(max(0, block.depth)) * 20)
            case "code-block":
                Text(block.text)
                    .font(.system(size: 15, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            case "atomic":
                atomicContent
            default:
                richText
            }
        }
        .font(.system(size: 17))
        .lineSpacing(7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var richText: some View {
        document.runs(in: block).reduce(Text("")) { result, run in
            result + styledText(for: run)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func styledText(for run: DraftRun) -> Text {
        var attributed = AttributedString(run.text)
        if let entity = run.entity, entity.type.uppercased() == "LINK",
           let rawURL = entity.data["url"]?.stringValue ?? entity.data["href"]?.stringValue,
           let url = URL(string: rawURL),
           ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            attributed.link = url
        }
        var text = Text(attributed)
        let styles = Set(run.styles.map { $0.uppercased() })
        if styles.contains("BOLD") { text = text.bold() }
        if styles.contains("ITALIC") { text = text.italic() }
        if styles.contains("STRIKETHROUGH") { text = text.strikethrough() }
        if styles.contains("CODE") { text = text.font(.system(size: 16, design: .monospaced)) }
        return text
    }

    private var headingSize: CGFloat {
        switch block.type {
        case "header-one": 28
        case "header-two": 24
        case "header-three": 21
        default: 18
        }
    }

    @ViewBuilder private var atomicContent: some View {
        if let key = block.entityRanges.first?.key,
           let entity = document.entities[key] {
            if let nativeView = atomicViewForEntity(entity) {
                nativeView
            } else {
                defaultAtomicContent(for: entity)
            }
        } else {
            Text("[Unsupported atomic content]").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func defaultAtomicContent(for entity: DraftEntity) -> some View {
        switch entity.type.uppercased() {
            case "DIVIDER": Divider()
            case "MEDIA":
                DraftMediaGalleryView(
                    items: entity.mediaItems,
                    caption: entity.data["caption"]?.stringValue,
                    mediaURLForID: mediaURLForID,
                    playbackURLForID: playbackURLForID
                )
            case "MARKDOWN":
                if let source = entity.data["markdown"]?.stringValue {
                    if let table = DraftMarkdownTable(markdown: source) {
                        DraftMarkdownTableView(table: table)
                    } else if let code = fencedCode(in: source) {
                        ScrollView(.horizontal) {
                            Text(code)
                                .font(.system(size: 15, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(16)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text((try? AttributedString(markdown: source)) ?? AttributedString(source))
                            .font(.system(size: 17))
                    }
                }
            case "TWEET":
                if let id = entity.data["post_id"]?.stringValue
                    ?? entity.data["tweet_id"]?.stringValue
                    ?? entity.data["tweetId"]?.stringValue,
                   let url = URL(string: "https://x.com/i/status/\(id)") {
                    Link("View post on X", destination: url)
                }
            default:
                Text("[Unsupported \(entity.type) content]").foregroundStyle(.secondary)
        }
    }

    private func fencedCode(in source: String) -> String? {
        let lines = source.trimmingCharacters(in: .newlines).components(separatedBy: "\n")
        guard lines.count >= 3, lines[0].hasPrefix("```"), lines.last == "```" else {
            return nil
        }
        return lines.dropFirst().dropLast().joined(separator: "\n")
    }
}

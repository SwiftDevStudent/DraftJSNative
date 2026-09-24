import Darwin
import DraftJSNative
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let checkRoundTrip = arguments.first == "--check-roundtrip"
guard arguments.count == (checkRoundTrip ? 2 : 1) else {
    FileHandle.standardError.write(Data(
        "Usage: draftjs-native [--check-roundtrip] <content-state-or-article.json>\n".utf8
    ))
    exit(64)
}

do {
    let url = URL(fileURLWithPath: arguments.last!)
    let data = try Data(contentsOf: url)
    if checkRoundTrip {
        let archive = try DraftArticleArchive(jsonData: data)
        let original = try JSONDecoder().decode(JSONValue.self, from: data)
        let encoded = try JSONDecoder().decode(JSONValue.self, from: archive.jsonData())
        guard original == encoded else {
            throw RoundTripError.changedJSON
        }
        print("Article JSON round trip matched: \(archive.article.document.blocks.count) blocks, "
            + "\(archive.article.document.entities.count) entities")
    } else {
        let root = try JSONSerialization.jsonObject(with: data)
        let article = (root as? [String: Any])?["content_state"] != nil
            ? try DraftArticlePayload(jsonData: data) : nil
        let document = try article?.document ?? DraftDocument(jsonData: data)
        let result = document.markdown { article?.imageURL(forMediaID: $0) }
        print(result.text)
        for warning in result.warnings {
            FileHandle.standardError.write(Data("warning: \(warning)\n".utf8))
        }
        for warning in document.defaultRendererWarnings(mediaURLForID: { article?.imageURL(forMediaID: $0) }) {
            FileHandle.standardError.write(Data("render warning: \(warning)\n".utf8))
        }
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}

private enum RoundTripError: Error {
    case changedJSON
}

import AppKit
import DraftJSNative
import Foundation
import SwiftUI

private struct ArticleFixture: Decodable {
    let title: String
    let content_state: DraftDocument
    let cover_media: ArticleMedia?
    let media_entities: [ArticleMedia]?
}

private struct ArticleMedia: Decodable {
    let media_id: String
    let media_info: MediaInfo
}

private struct MediaInfo: Decodable {
    let original_img_url: String?
}

private final class PreviewAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let input = CommandLine.arguments.count == 2
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : Bundle.main.url(forResource: "sample-article", withExtension: "json")!
private let inputData = try Data(contentsOf: input)
private let fixture = try? JSONDecoder().decode(ArticleFixture.self, from: inputData)
private let document = try fixture?.content_state ?? DraftDocument(jsonData: inputData)
private let title = fixture?.title ?? "Draft.js bilingual sample"
private let mediaURLs = Dictionary(uniqueKeysWithValues: (fixture?.media_entities ?? []).compactMap { media in
    media.media_info.original_img_url.flatMap(URL.init(string:)).map { (media.media_id, $0) }
})
let app = NSApplication.shared
private let appDelegate = PreviewAppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)

let content = ScrollView {
    DraftArticleView(
        title: title,
        document: document,
        coverURL: fixture?.cover_media?.media_info.original_img_url.flatMap(URL.init(string:)),
        mediaURLForID: { mediaURLs[$0] }
    )
        .frame(maxWidth: .infinity)
}
.background(Color.black)
.foregroundStyle(.white)
.preferredColorScheme(.dark)

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 900, height: 850),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = title
window.contentView = NSHostingView(rootView: content)
window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()

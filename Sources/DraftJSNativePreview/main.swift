import AppKit
import DraftJSNative
import Foundation
import SwiftUI

private final class PreviewAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let input = CommandLine.arguments.count == 2
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : Bundle.main.url(forResource: "sample-article-envelope", withExtension: "json")!
private let inputData = try Data(contentsOf: input)
private let article = try? DraftArticlePayload(jsonData: inputData)
private let document = try article?.document ?? DraftDocument(jsonData: inputData)
private let title = article?.title ?? "Draft.js bilingual sample"
let app = NSApplication.shared
private let appDelegate = PreviewAppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)

let content = ScrollView {
    DraftArticleView(
        title: title,
        document: document,
        coverURL: article?.coverMedia?.imageURL,
        mediaURLForID: { article?.imageURL(forMediaID: $0) }
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

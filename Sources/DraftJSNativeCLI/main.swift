import Darwin
import DraftJSNative
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: draftjs-native <content-state.json>\n".utf8))
    exit(64)
}

do {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    let document = try DraftDocument(jsonData: Data(contentsOf: url))
    let result = document.markdown()
    print(result.text)
    for warning in result.warnings {
        FileHandle.standardError.write(Data("warning: \(warning)\n".utf8))
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}

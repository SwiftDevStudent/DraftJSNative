// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DraftJSNative",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "DraftJSNative", targets: ["DraftJSNative"]),
        .executable(name: "draftjs-native", targets: ["DraftJSNativeCLI"]),
        .executable(name: "draftjs-native-preview", targets: ["DraftJSNativePreview"]),
    ],
    targets: [
        .target(name: "DraftJSNative"),
        .executableTarget(name: "DraftJSNativeCLI", dependencies: ["DraftJSNative"]),
        .executableTarget(name: "DraftJSNativePreview", dependencies: ["DraftJSNative"]),
        .testTarget(name: "DraftJSNativeTests", dependencies: ["DraftJSNative"]),
    ]
)

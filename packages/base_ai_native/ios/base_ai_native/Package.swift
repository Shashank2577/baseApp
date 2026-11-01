// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "base_ai_native",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .library(name: "base-ai-native", targets: ["base_ai_native"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // The engines. They must be dependencies of this target (not only of the
        // Runner) for the bridges' `canImport` checks to see them.
        // Exactly 0.18.1: the 0.19.0 tag's Swift sources call a newer C API than the
        // binary it downloads, so it does not compile (found building PhoneDots for iOS).
        .package(url: "https://github.com/google-ai-edge/LiteRT-LM.git", exact: "0.18.1"),
        .package(url: "https://github.com/Desert-Ant-Labs/desert-ant-core.git", from: "4.2.1"),
    ],
    targets: [
        .target(
            name: "base_ai_native",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "LiteRTLM", package: "litert-lm"),
            ] + ["Voz", "Who", "Ear", "Clear", "Uhm", "Redact", "Tongue", "Emo", "Gist", "Eye", "Moderator"].map {
                .product(name: $0, package: "desert-ant-core")
            },
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        )
    ]
)

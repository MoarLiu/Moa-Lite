// swift-tools-version: 5.9
import Foundation
import PackageDescription

let package = Package(
    name: "MoaLite",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Moa-Lite", targets: ["MoaLite"])
    ],
    targets: [
        .executableTarget(
            name: "MoaLite",
            path: "macos-menu-bar",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Combine"),
                .linkedFramework("CryptoKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)

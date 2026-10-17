// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().resolvingSymlinksInPath()
let traceletRoot = packageDir.appendingPathComponent("../../../..").standardized.path

let package = Package(
    name: "tracelet_ios",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "tracelet-ios", targets: ["tracelet_ios"])
    ],
    dependencies: [
        // Consumed via Swift Package Manager when imported as a Flutter plugin.
        // It points to the root of the Tracelet monorepo where the SPM configuration resides.
        
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "tracelet_ios",
            dependencies: [
                "TraceletCore",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/tracelet_ios"
        )
    ]
)

extension Package {
    func addRemoteBinary() {
        targets.append(
            .binaryTarget(
                name: "TraceletCore",
                url: "https://github.com/Ikolvi/Tracelet/releases/download/tracelet_ios-v3.8.8/TraceletCore.xcframework.zip",
                checksum: "0c7b8cd6a2a817be3aece2b8913e895d5efa8d045a174dbc9b5deb9f66154703"
            )
        )
    }
}
package.addRemoteBinary()

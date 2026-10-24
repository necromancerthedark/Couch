// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Couch",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Phase 0 feasibility spike (done): enumerate + stream controller state.
        .executableTarget(
            name: "pad-dump",
            path: "Sources/pad-dump"
        ),
        // The menu-bar media-remote app (Phase 1+).
        .executableTarget(
            name: "Couch",
            path: "Sources/Couch"
        ),
        .testTarget(
            name: "CouchTests",
            dependencies: ["Couch"],
            path: "Tests/CouchTests"
        )
    ]
)
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "BestShotRanking",
    platforms: [.macOS(.v14)],
    products: [.library(name: "RankingCore", targets: ["RankingCore"])],
    targets: [
        .target(name: "RankingCore", path: "BestShot/Ranking"),
        .target(name: "PhotoCopyCore", path: "BestShot/Photos"),
        .testTarget(name: "RankingCoreTests", dependencies: ["RankingCore"], path: "Tests/RankingCoreTests"),
        .testTarget(name: "PhotoCopyCoreTests", dependencies: ["PhotoCopyCore"], path: "Tests/PhotoCopyCoreTests")
    ]
)

// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "BestShotRanking",
    platforms: [.macOS(.v14)],
    products: [.library(name: "RankingCore", targets: ["RankingCore"])],
    targets: [
        .target(name: "RankingCore", path: "BestShot/Ranking"),
        .testTarget(name: "RankingCoreTests", dependencies: ["RankingCore"], path: "Tests/RankingCoreTests")
    ]
)

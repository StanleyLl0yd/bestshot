import XCTest
@testable import RankingCore

final class RankingCoreTests: XCTestCase {
    func testOrderingAndTieBreak() {
        let values = [
            PhotoSignals(sourceIndex: 2, sharpness: 9, exposurePenalty: 0.2, faceCount: 0, faceQuality: nil),
            PhotoSignals(sourceIndex: 0, sharpness: 9, exposurePenalty: 0.2, faceCount: 0, faceQuality: nil),
            PhotoSignals(sourceIndex: 1, sharpness: 0, exposurePenalty: 0.9, faceCount: 0, faceQuality: nil)
        ]
        XCTAssertEqual(Ranker.rank(values).map(\.sourceIndex), [0, 2, 1])
    }
    func testNonFiniteSignalsAreExcluded() {
        XCTAssertEqual(Ranker.rank([
            .init(sourceIndex: 0, sharpness: .nan, exposurePenalty: 0.2, faceCount: 0, faceQuality: nil),
            .init(sourceIndex: 1, sharpness: 2, exposurePenalty: 0.1, faceCount: 0, faceQuality: nil)
        ]).map(\.sourceIndex), [1])
    }
    func testMissingQualityAndGroupCaution() {
        let scores = Ranker.rank([
            .init(sourceIndex: 0, sharpness: 2, exposurePenalty: 0.1, faceCount: 3, faceQuality: 0.99),
            .init(sourceIndex: 1, sharpness: 2, exposurePenalty: 0.1, faceCount: 2, faceQuality: 0.01)
        ])
        XCTAssertEqual(scores[0].sourceIndex, 0)
        XCTAssertTrue(scores.allSatisfy(\.uncertain))
        XCTAssertEqual(scores[0].score, scores[1].score, accuracy: 0.000001)
    }
    func testNearTiesAreMarked() {
        XCTAssertTrue(Ranker.rank([
            .init(sourceIndex: 0, sharpness: 1, exposurePenalty: 0.1, faceCount: 1, faceQuality: nil),
            .init(sourceIndex: 1, sharpness: 1, exposurePenalty: 0.1, faceCount: 1, faceQuality: nil)
        ]).allSatisfy(\.uncertain))
    }
}

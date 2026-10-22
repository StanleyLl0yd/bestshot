import Foundation

/// Only relative scores within one user-selected burst have meaning.
public struct PhotoSignals: Sendable, Equatable {
    public let sourceIndex: Int
    public let sharpness: Double
    public let exposurePenalty: Double
    public let faceCount: Int
    public let faceQuality: Double?
    public init(sourceIndex: Int, sharpness: Double, exposurePenalty: Double,
                faceCount: Int, faceQuality: Double?) {
        self.sourceIndex = sourceIndex
        self.sharpness = sharpness
        self.exposurePenalty = exposurePenalty
        self.faceCount = faceCount
        self.faceQuality = faceQuality
    }
}

public struct RankedPhoto: Sendable, Equatable {
    public let sourceIndex: Int
    public let score: Double
    public let reasons: [String]
    public let uncertain: Bool
}

public enum Ranker {
    public static func rank(_ photos: [PhotoSignals]) -> [RankedPhoto] {
        let safe = photos.filter {
            $0.sharpness.isFinite && $0.exposurePenalty.isFinite &&
            $0.sharpness >= 0 && (0...1).contains($0.exposurePenalty) &&
            ($0.faceQuality == nil || ($0.faceQuality!.isFinite && (0...1).contains($0.faceQuality!))) &&
            $0.faceCount >= 0
        }
        guard !safe.isEmpty else { return [] }
        let transformed = safe.map { log1p($0.sharpness) }
        let low = transformed.min() ?? 0
        let high = transformed.max() ?? low
        let faceCountsVary = Set(safe.map(\.faceCount)).count > 1
        let ranked = safe.map { item -> RankedPhoto in
            // Do not compare face-capture quality between different people in groups.
            let quality = item.faceCount == 1 ? item.faceQuality : nil
            let rawSharpness = log1p(item.sharpness)
            let sharpness = high - low < 0.0001 ? 0.5 : (rawSharpness - low) / (high - low)
            let technical = 0.70 * sharpness + 0.30 * (1 - item.exposurePenalty)
            let value = quality.map { 0.80 * technical + 0.20 * $0 } ?? technical
            var reasons: [String] = []
            if sharpness > 0.70 { reasons.append("sharp") }
            if item.exposurePenalty < 0.18 { reasons.append("exposure") }
            if quality != nil { reasons.append("face-capture") }
            if item.faceCount == 0 { reasons.append("no-faces") }
            if faceCountsVary { reasons.append("face-count-varies") }
            return RankedPhoto(sourceIndex: item.sourceIndex, score: min(1, max(0, value)),
                               reasons: reasons, uncertain: faceCountsVary)
        }.sorted {
            if abs($0.score - $1.score) < 0.000000001 { return $0.sourceIndex < $1.sourceIndex }
            return $0.score > $1.score
        }
        let ambiguous = ranked.count > 1 && ranked[0].score - ranked[1].score < 0.055
        return ranked.map {
            RankedPhoto(sourceIndex: $0.sourceIndex, score: $0.score,
                        reasons: $0.reasons, uncertain: $0.uncertain || ambiguous)
        }
    }
}

package com.sl.bestshot.ranking

import kotlin.math.abs
import kotlin.math.ln

data class PhotoSignals(
    val index: Int,
    val sharpness: Double,
    val exposurePenalty: Double,
    val faceCount: Int,
    val faceQuality: Double? = null,
    val eyesOpen: Double? = null,
    val faceDetectionFailed: Boolean = false
)

data class RankedPhoto(
    val index: Int,
    val score: Double,
    val reasons: List<String>,
    val uncertain: Boolean
)

object Ranking {
    fun rank(input: List<PhotoSignals>): List<RankedPhoto> {
        val valid = input.filter {
            it.sharpness.isFinite() && it.sharpness >= 0 &&
                it.exposurePenalty.isFinite() && it.exposurePenalty in 0.0..1.0 &&
                it.faceCount >= 0 &&
                (it.faceQuality == null || (it.faceQuality.isFinite() && it.faceQuality in 0.0..1.0)) &&
                (it.eyesOpen == null || (it.eyesOpen.isFinite() && it.eyesOpen in 0.0..1.0))
        }
        if (valid.isEmpty()) return emptyList()
        val transformed = valid.map { ln(1 + it.sharpness) }
        val low = transformed.min()
        val high = transformed.max()
        val varyingCounts = valid.filterNot { it.faceDetectionFailed }.map { it.faceCount }.distinct().size > 1
        val detectorFailed = valid.any { it.faceDetectionFailed }
        val scored = valid.map { item ->
            val s = if (high - low < 0.0001) 0.5 else (ln(1 + item.sharpness) - low) / (high - low)
            val technical = 0.70 * s + 0.30 * (1 - item.exposurePenalty)
            // Eye probability only for one sufficiently frontal face. Never infer closed eyes from missing data.
            val eyes = if (item.faceCount == 1) item.eyesOpen else null
            val score = if (eyes == null) technical else 0.82 * technical + 0.18 * eyes
            val notes = buildList {
                if (s > 0.7) add("sharp")
                if (item.exposurePenalty < 0.18) add("exposure")
                if (eyes != null) add("eye-signal")
                if (item.faceCount == 0 && !item.faceDetectionFailed) add("no-faces")
                if (item.faceDetectionFailed) add("face-detector-unavailable")
                if (varyingCounts) add("face-count-varies")
            }
            RankedPhoto(item.index, score.coerceIn(0.0, 1.0), notes, varyingCounts || detectorFailed)
        }.sortedWith(compareByDescending<RankedPhoto> { it.score }.thenBy { it.index })
        val nearTie = scored.size >= 2 && abs(scored[0].score - scored[1].score) < 0.055
        return scored.map { it.copy(uncertain = it.uncertain || nearTie) }
    }
}

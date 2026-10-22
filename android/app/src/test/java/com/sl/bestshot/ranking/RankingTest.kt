package com.sl.bestshot.ranking

import org.junit.Assert.*
import org.junit.Test

class RankingTest {
    @Test fun tieUsesInputOrder() {
        val scores = Ranking.rank(listOf(
            PhotoSignals(3, 3.0, .1, 0),
            PhotoSignals(1, 3.0, .1, 0)
        ))
        assertEquals(listOf(1,3), scores.map { it.index })
        assertTrue(scores.all { it.uncertain })
    }
    @Test fun nonFiniteExcluded() {
        assertEquals(1, Ranking.rank(listOf(
            PhotoSignals(0, Double.NaN, .2, 0),
            PhotoSignals(1, 2.0, .1, 0)
        )).size)
    }
    @Test fun groupDoesNotUseSinglePersonQualityOrRewardFewerFaces() {
        val scores = Ranking.rank(listOf(
            PhotoSignals(0, 3.0, .2, 4, faceQuality = 1.0),
            PhotoSignals(1, 3.0, .2, 2, faceQuality = 0.0)
        ))
        assertEquals(scores[0].score, scores[1].score, .000001)
        assertTrue(scores.all { it.uncertain })
    }
    @Test fun unknownEyeSignalIsNotTreatedAsClosedEyes() {
        val scores = Ranking.rank(listOf(
            PhotoSignals(0, 3.0, .2, 1, eyesOpen = null),
            PhotoSignals(1, 3.0, .2, 1, eyesOpen = null)
        ))
        assertEquals(scores[0].score, scores[1].score, .000001)
    }
    @Test fun detectorFailurePreservesTechnicalRankingAndSignalsUncertainty() {
        val ranked = Ranking.rank(listOf(
            PhotoSignals(0, 4.0, .15, 0, faceDetectionFailed = true),
            PhotoSignals(1, 5.0, .25, 1)
        ))
        assertEquals(2, ranked.size)
        assertTrue(ranked.all { it.uncertain })
        val fallback = ranked.first { it.index == 0 }
        assertTrue(fallback.reasons.contains("face-detector-unavailable"))
        assertFalse(fallback.reasons.contains("no-faces"))
    }

}

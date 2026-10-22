package com.sl.bestshot.analysis

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.sl.bestshot.ranking.PhotoSignals
import java.io.IOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.coroutines.suspendCoroutine

data class AnalyzedPhoto(val uri: Uri, val index: Int, val signals: PhotoSignals?, val error: String?)

class ImageAnalyzer(private val context: Context) : AutoCloseable {
    private val detector: FaceDetector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
            .build()
    )

    suspend fun analyze(uri: Uri, index: Int): AnalyzedPhoto = withContext(Dispatchers.Default) {
        var bitmap: Bitmap? = null
        try {
            bitmap = decodeScaled(uri)
            val pixels = bitmap ?: throw IOException("Cannot decode image")
            val (sharpness, exposure) = measure(pixels)
            // Wait for the detector to finish even if cancellation arrives, so its
            // InputImage never refers to a recycled Bitmap.
            var detectorWarning: String? = null
            val faces = try {
                suspendCoroutine<List<Face>> { continuation ->
                    detector.process(InputImage.fromBitmap(pixels, 0))
                        .addOnSuccessListener { continuation.resume(it) }
                        .addOnFailureListener { continuation.resumeWithException(it) }
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                detectorWarning = "Face detection unavailable: " + (e.message ?: "unknown error")
                emptyList()
            }
            // Only use probabilities for one near-front-facing face.
            val face = faces.singleOrNull()
            val left = face?.leftEyeOpenProbability
            val right = face?.rightEyeOpenProbability
            val eyeConfidence = if (face != null && left != null && right != null &&
                abs(face.headEulerAngleY) <= 18 && abs(face.headEulerAngleZ) <= 18
            ) min(left.toDouble(), right.toDouble()) else null
            AnalyzedPhoto(uri, index,
                PhotoSignals(index, sharpness, exposure, faces.size,
                    eyesOpen = eyeConfidence, faceDetectionFailed = detectorWarning != null),
                detectorWarning)
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            AnalyzedPhoto(uri, index, null, e.message ?: "Image processing failed")
        } finally {
            bitmap?.recycle()
        }
    }

    private fun decodeScaled(uri: Uri): Bitmap {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        val boundsStream = resolver.openInputStream(uri) ?: throw IOException("Cannot open image")
        boundsStream.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IOException("Unknown image format")
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > 1400) sample *= 2
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val decoded = resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: throw IOException("Cannot decode image")
        val orientation = resolver.openInputStream(uri)?.use {
            runCatching { ExifInterface(it).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            ) }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        } ?: ExifInterface.ORIENTATION_NORMAL
        val matrix = Matrix().apply {
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> { postRotate(90f); postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_TRANSVERSE -> { postRotate(270f); postScale(-1f, 1f) }
            }
        }
        if (matrix.isIdentity) return decoded
        return try {
            Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true).also {
                if (it !== decoded) decoded.recycle()
            }
        } catch (e: Exception) {
            decoded.recycle()
            throw e
        }
    }

    private fun measure(bitmap: Bitmap): Pair<Double, Double> {
        val width = max(1, min(320, bitmap.width))
        val height = max(1, min(320, bitmap.height))
        val reduced = Bitmap.createScaledBitmap(bitmap, width, height, true)
        try {
            val rgb = IntArray(width * height)
            reduced.getPixels(rgb, 0, width, 0, 0, width, height)
            val gray = IntArray(rgb.size) { i ->
                val color = rgb[i]
                (0.2126 * Color.red(color) + 0.7152 * Color.green(color) +
                    0.0722 * Color.blue(color)).toInt()
            }
            var energy = 0.0
            var edges = 0
            for (y in 1 until height - 1) {
                for (x in 1 until width - 1) {
                    val i = y * width + x
                    val lap = gray[i-1] + gray[i+1] + gray[i-width] + gray[i+width] - 4*gray[i]
                    energy += (lap * lap).toDouble()
                    edges++
                }
            }
            val clipped = gray.count { it <= 5 || it >= 250 }.toDouble() / gray.size
            val mean = gray.average() / 255.0
            val meanPenalty = max(0.0, abs(mean - 0.5) - 0.30) / 0.5
            return Pair(energy / max(1, edges), (0.80 * clipped + 0.20 * meanPenalty).coerceIn(0.0, 1.0))
        } finally {
            if (reduced !== bitmap) reduced.recycle()
        }
    }

    override fun close() { detector.close() }
}

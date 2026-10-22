package com.sl.bestshot

import android.app.Application
import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.sl.bestshot.analysis.AnalyzedPhoto
import com.sl.bestshot.analysis.ImageAnalyzer
import com.sl.bestshot.ranking.RankedPhoto
import com.sl.bestshot.ranking.Ranking
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class ScreenState(
    val source: List<Uri> = emptyList(),
    val results: List<AnalyzedPhoto> = emptyList(),
    val ranking: List<RankedPhoto> = emptyList(),
    val progress: Int = 0,
    val processing: Boolean = false,
    val selected: Set<Int> = emptySet(),
    val message: String? = null
)

class BestShotViewModel(app: Application) : AndroidViewModel(app) {
    private val mutable = MutableStateFlow(ScreenState())
    val state = mutable.asStateFlow()
    private var job: Job? = null
    private var generation: Long = 0L

    fun start(uris: List<Uri>) {
        val unique = uris.distinct()
        if (unique.size !in 2..30) {
            mutable.value = mutable.value.copy(message = "Выберите 2-30 разных фотографий / Choose 2-30 photos")
            return
        }
        val ticket = ++generation
        job?.cancel()
        mutable.value = ScreenState(source = unique, processing = true)
        job = viewModelScope.launch {
            val output = mutableListOf<AnalyzedPhoto>()
            ImageAnalyzer(getApplication()).use { analyzer ->
                try {
                    unique.forEachIndexed { index, uri ->
                        kotlinx.coroutines.currentCoroutineContext().ensureActive()
                        output += analyzer.analyze(uri, index)
                        if (ticket == generation) mutable.value = mutable.value.copy(progress = index + 1)
                    }
                    val ranking = Ranking.rank(output.mapNotNull { it.signals })
                    if (ticket == generation) mutable.value = mutable.value.copy(
                        results = output,
                        ranking = ranking,
                        selected = ranking.take(3).map { it.index }.toSet(),
                        processing = false,
                        message = if (ranking.size < 2) "Недостаточно фотографий / Too few readable images" else null
                    )
                } catch (_: CancellationException) {
                    if (ticket == generation) mutable.value = mutable.value.copy(processing = false, message = "Анализ отменён / Cancelled")
                } catch (e: Exception) {
                    if (ticket == generation) mutable.value = mutable.value.copy(processing = false, message = e.message)
                }
            }
        }
    }

    fun cancel() {
        job?.cancel()
        mutable.value = mutable.value.copy(processing = false, message = "Анализ отменён / Cancelled")
    }
    fun select(index: Int, checked: Boolean) {
        val old = mutable.value.selected
        mutable.value = mutable.value.copy(selected = if (checked) old + index else old - index)
    }
    fun dismissMessage() { mutable.value = mutable.value.copy(message = null) }

    fun export(directory: Uri) {
        val snapshot = mutable.value
        val indices = snapshot.selected.sorted()
        if (indices.isEmpty()) return
        viewModelScope.launch {
            val outcome = withContext(Dispatchers.IO) {
                val resolver = getApplication<Application>().contentResolver
                val folder = DocumentFile.fromTreeUri(getApplication(), directory)
                    ?: return@withContext "Cannot access selected directory"
                var saved = 0
                for (index in indices) {
                    val uri = snapshot.source.getOrNull(index) ?: continue
                    var name = displayName(resolver, uri, index)
                    val dot = name.lastIndexOf('.')
                    val stem = if (dot > 0) name.substring(0, dot) else name
                    val ext = if (dot > 0) name.substring(dot) else ""
                    var suffix = 1
                    while (folder.findFile(name) != null) {
                        name = stem + "-" + suffix + ext
                        suffix++
                    }
                    val target = folder.createFile(resolver.getType(uri) ?: "application/octet-stream", name)
                        ?: return@withContext "Cannot create export file"
                    try {
                        val input = resolver.openInputStream(uri) ?: throw IOException("Cannot open source")
                        val output = resolver.openOutputStream(target.uri, "w")
                            ?: throw IOException("Cannot open destination")
                        input.use { source -> output.use { destination -> source.copyTo(destination) } }
                        saved++
                    } catch (e: Exception) {
                        target.delete()
                        return@withContext "Exported " + saved + ". " + (e.message ?: "Export error")
                    }
                }
                "Exported " + saved + " original-quality copies"
            }
            mutable.value = mutable.value.copy(message = outcome)
        }
    }

    private fun displayName(resolver: ContentResolver, uri: Uri, index: Int): String {
        val candidate = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        } ?: "photo-" + (index + 1) + ".jpg"
        return candidate.substringAfterLast('/').substringAfterLast('\\')
            .take(120).ifBlank { "photo-" + (index + 1) + ".jpg" }
    }
}

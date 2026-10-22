package com.sl.bestshot

import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme(colorScheme = if (androidx.compose.foundation.isSystemInDarkTheme())
            darkColorScheme() else lightColorScheme()) { BestShotScreen() } }
    }
}
private fun tr(ru: String, en: String): String =
    if (Locale.getDefault().language == "ru") ru else en

@Composable
private fun BestShotScreen(vm: BestShotViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    val choose = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxItems = 30)
    ) { photos -> if (photos.isNotEmpty()) vm.start(photos) }
    val export = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) {
        if (it != null) vm.export(it)
    }
    var compare by remember { mutableStateOf(false) }
    var showWarnings by remember { mutableStateOf(false) }
    var compareLeft by remember { mutableIntStateOf(0) }
    var compareRight by remember { mutableIntStateOf(1) }
    var zoom by remember { mutableFloatStateOf(1f) }
    LaunchedEffect(state.source) {
        compareLeft = 0
        compareRight = 1
        zoom = 1f
        showWarnings = false
    }
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("BestShot", style = MaterialTheme.typography.headlineLarge)
        Text(tr("Выберите 2-30 похожих снимков. Обработка полностью локальная.",
            "Choose 2-30 similar photos. All analysis stays on-device."))
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = { choose.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                enabled = !state.processing
            ) { Text(tr("Выбрать фото", "Choose photos")) }
            if (state.processing) OutlinedButton(onClick = vm::cancel) {
                Text(tr("Отмена", "Cancel"))
            }
        }
        if (state.processing) {
            LinearProgressIndicator(progress = { state.progress.toFloat() / state.source.size.coerceAtLeast(1) },
                modifier = Modifier.fillMaxWidth())
            Text(state.progress.toString() + "/" + state.source.size)
        }
        val warnings = state.results.filter { it.error != null }
        if (warnings.isNotEmpty()) {
            TextButton(onClick = { showWarnings = !showWarnings }) {
                Text(tr("Проблемы с файлами: ", "File warnings: ") + warnings.size)
            }
            if (showWarnings) {
                Column(Modifier.heightIn(max = 160.dp).verticalScroll(rememberScrollState())) {
                    warnings.forEach { item ->
                        Text("#" + (item.index + 1) + ": " + (item.error ?: ""),
                             style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        if (state.ranking.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            if (state.ranking.first().uncertain) {
                Text(tr("Кадры близки или лица обнаружены непоследовательно. Сравните визуально.",
                    "Near tie or varying face counts. Compare visually."),
                    color = MaterialTheme.colorScheme.error)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { compare = true }, enabled = state.ranking.size >= 2) {
                    Text(tr("Сравнить", "Compare"))
                }
                Button(onClick = { export.launch(null) },
                    enabled = state.selected.isNotEmpty() && !state.exporting && !state.processing) {
                    Text(if (state.exporting) tr("Экспорт...", "Exporting...")
                         else tr("Экспорт", "Export"))
                }
            }
            LazyVerticalGrid(columns = GridCells.Adaptive(150.dp),
                contentPadding = PaddingValues(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(state.ranking, key = { it.index }) { rank ->
                    Card {
                        Column(Modifier.padding(8.dp)) {
                            PhotoPreview(state.source[rank.index],
                                Modifier.fillMaxWidth().height(145.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("#" + (state.ranking.indexOf(rank) + 1))
                                Spacer(Modifier.weight(1f))
                                Checkbox(checked = rank.index in state.selected,
                                    onCheckedChange = { vm.select(rank.index, it) })
                            }
                            Text(rank.reasons.joinToString(" · ") {
                                when (it) {
                                    "sharp" -> tr("Резче", "Sharper")
                                    "exposure" -> tr("Меньше пересветов", "Less clipping")
                                    "eye-signal" -> tr("Глаза, вероятно, открыты", "Eyes likely open")
                                    "face-count-varies" -> tr("Число лиц различается", "Face counts differ")
                                    "no-faces" -> tr("Без обнаруженных лиц", "No faces found")
                                    "face-detector-unavailable" -> tr("Оценены технические показатели без AI", "Technical-only analysis")
                                    else -> it
                                }
                            }, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        } else if (!state.processing) {
            Spacer(Modifier.height(28.dp))
            Text(tr("Результаты появятся после анализа.", "Ranked photos will appear here."))
        }
    }
    if (state.message != null) AlertDialog(
        onDismissRequest = vm::dismissMessage,
        confirmButton = { TextButton(onClick = vm::dismissMessage) { Text("OK") } },
        title = { Text("BestShot") },
        text = { Text(state.message ?: "") })
    if (compare && state.ranking.size >= 2) Dialog(onDismissRequest = { compare = false }) {
        Card(Modifier.fillMaxWidth(0.98f)) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(12.dp)) {
                Text(tr("Сравнение кадров", "Compare photos"),
                    style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onClick = {
                            compareLeft = (compareLeft - 1 + state.ranking.size) % state.ranking.size
                        }) { Text("‹") }
                        Text("#" + (compareLeft + 1))
                        TextButton(onClick = {
                            compareLeft = (compareLeft + 1) % state.ranking.size
                        }) { Text("›") }
                    }
                    Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onClick = {
                            compareRight = (compareRight - 1 + state.ranking.size) % state.ranking.size
                        }) { Text("‹") }
                        Text("#" + (compareRight + 1))
                        TextButton(onClick = {
                            compareRight = (compareRight + 1) % state.ranking.size
                        }) { Text("›") }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    PhotoPreview(state.source[state.ranking[compareLeft].index],
                        Modifier.weight(1f).height(280.dp).graphicsLayer {
                            scaleX = zoom
                            scaleY = zoom
                            clip = true
                        }, maxEdge = if (zoom > 1.5f) 2000 else 1200)
                    PhotoPreview(state.source[state.ranking[compareRight].index],
                        Modifier.weight(1f).height(280.dp).graphicsLayer {
                            scaleX = zoom
                            scaleY = zoom
                            clip = true
                        }, maxEdge = if (zoom > 1.5f) 2000 else 1200)
                }
                Text(tr("Масштаб", "Zoom") + " " + (zoom * 100).toInt() + "%")
                Slider(value = zoom, onValueChange = { zoom = it }, valueRange = 1f..3f)
                TextButton(onClick = { compare = false }) { Text(tr("Закрыть", "Close")) }
            }
        }
    }
}

@Composable
private fun PhotoPreview(uri: Uri, modifier: Modifier = Modifier, maxEdge: Int = 700) {
    val context = LocalContext.current
    val thumbnail by produceState<Bitmap?>(initialValue = null, uri, maxEdge) {
        value = withContext(Dispatchers.IO) {
            runCatching {
                // ImageDecoder handles JPEG/HEIF/PNG orientation on API 29+.
                val source = ImageDecoder.createSource(context.contentResolver, uri)
                ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                    var sample = 1
                    val edge = maxOf(info.size.width, info.size.height)
                    while (edge / sample > maxEdge) sample *= 2
                    decoder.setTargetSampleSize(sample)
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                }
            }.getOrNull()
        }
    }
    if (thumbnail != null) Image(thumbnail!!.asImageBitmap(),
        contentDescription = tr("Фотография", "Photo"), modifier = modifier,
        contentScale = ContentScale.Fit)
    else Box(modifier, contentAlignment = Alignment.Center) {
        Text(tr("Предпросмотр недоступен", "Preview unavailable"),
            style = MaterialTheme.typography.bodySmall)
    }
}

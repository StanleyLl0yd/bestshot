package com.sl.bestshot

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
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
                Button(onClick = { export.launch(null) }, enabled = state.selected.isNotEmpty()) {
                    Text(tr("Экспорт", "Export"))
                }
            }
            val failed = state.results.count { it.error != null }
            if (failed > 0) Text(tr("Не обработано: ", "Unreadable: ") + failed)
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
    if (compare && state.ranking.size >= 2) AlertDialog(
        onDismissRequest = { compare = false },
        confirmButton = { TextButton(onClick = { compare = false }) { Text(tr("Закрыть", "Close")) } },
        title = { Text(tr("Сравнение", "Compare")) },
        text = {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                state.ranking.take(2).forEach {
                    PhotoPreview(state.source[it.index], Modifier.weight(1f).height(250.dp))
                }
            }
        })
}

@Composable
private fun PhotoPreview(uri: Uri, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val thumbnail by produceState<Bitmap?>(initialValue = null, uri) {
        value = withContext(Dispatchers.IO) {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 500) sample *= 2
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
            }
        }
    }
    if (thumbnail != null) Image(thumbnail!!.asImageBitmap(),
        contentDescription = tr("Фотография", "Photo"), modifier = modifier,
        contentScale = ContentScale.Fit)
    else Box(modifier, contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

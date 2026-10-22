import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var urls: [URL] = []
    @State private var results: [PhotoAnalysis] = []
    @State private var ranked: [RankedPhoto] = []
    @State private var selected: Set<Int> = []
    @State private var active: Task<Void, Never>?
    @State private var processed = 0
    @State private var analysisGeneration: UInt64 = 0
    @State private var alert: String?
    @State private var compare = false
    @State private var compareLeft = 0
    @State private var compareRight = 1
    @State private var compareZoom = 1.0

    private var running: Bool { active != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text("BestShot").font(.largeTitle.bold())
                    Text(L.text("Выберите 2-30 похожих снимков. Обработка только на устройстве.",
                                "Choose 2-30 similar photos. All analysis is on-device."))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L.text("Выбрать фотографии", "Choose Photos")) { pick() }.disabled(running)
                if running { Button(L.text("Отмена", "Cancel")) { active?.cancel() } }
            }
            if running {
                ProgressView(value: Double(processed), total: Double(max(1, urls.count)))
                Text("\(processed) / \(urls.count)").font(.caption)
            }
            if !ranked.isEmpty {
                if ranked.first?.uncertain == true {
                    Text(L.text("Результаты близки или лица обнаруживаются непоследовательно. Проверьте визуально.",
                                "Results are close or face detection varies. Please compare visually."))
                        .foregroundStyle(.orange)
                }
                HStack {
                    Text(L.text("Рекомендации", "Recommendations")).font(.headline)
                    Spacer()
                    Button(L.text("Сравнить два лучших", "Compare top two")) { compare = true }
                        .disabled(ranked.count < 2)
                    Button(L.text("Экспорт выбранных", "Export selected")) { export() }
                        .disabled(selected.isEmpty)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 165, maximum: 240))], spacing: 12) {
                        ForEach(ranked, id: \.sourceIndex) { rank in
                            let index = rank.sourceIndex
                            VStack(alignment: .leading) {
                                PreviewImage(url: urls[index], size: 210)
                                HStack {
                                    Text("#\((ranked.firstIndex(of: rank) ?? 0) + 1)").bold()
                                    Spacer()
                                    Toggle(isOn: Binding(
                                        get: { selected.contains(index) },
                                        set: { if $0 { selected.insert(index) } else { selected.remove(index) } }
                                    )) { Text(L.text("Выбрать", "Select")) }
                                        .labelsHidden()
                                }
                                Text(urls[index].lastPathComponent).lineLimit(1)
                                Text(explain(rank)).font(.caption).foregroundStyle(.secondary)
                            }.padding(9).background(.quaternary.opacity(0.45),
                                in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            } else {
                Spacer()
                ContentUnavailableView(L.text("Нет результатов", "No results"),
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(L.text("Выберите серию, чтобы увидеть рекомендации.",
                                             "Choose a photo series to see recommendations.")))
                Spacer()
            }
            let errors = results.filter { $0.error != nil }
            if !errors.isEmpty {
                DisclosureGroup(
                    L.text("Проблемы с файлами: \(errors.count)", "File warnings: \(errors.count)")
                ) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(errors, id: \.sourceIndex) { item in
                                Text("\(item.url.lastPathComponent): \(item.error ?? "")")
                                    .font(.caption).textSelection(.enabled)
                            }
                        }
                    }.frame(maxHeight: 160)
                }.foregroundStyle(.orange)
            }
        }
        .padding(20)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            guard !running, !providers.isEmpty else { return false }
            let group = DispatchGroup()
            let collector = FileDropCollector()
            for (index, provider) in providers.enumerated() {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { collector.append(url, index: index) }
                    group.leave()
                }
            }
            // A multi-file drop is ONE selection, not separate one-photo requests.
            group.notify(queue: .main) {
                Task { @MainActor in
                    start(urls: collector.snapshot())
                }
            }
            return true
        }
        .sheet(isPresented: $compare) {
            VStack(spacing: 12) {
                HStack {
                    Picker(L.text("Левый кадр", "Left photo"), selection: $compareLeft) {
                        ForEach(0..<ranked.count, id: \.self) { i in
                            Text("#\(i + 1) \(urls[ranked[i].sourceIndex].lastPathComponent)").tag(i)
                        }
                    }
                    Picker(L.text("Правый кадр", "Right photo"), selection: $compareRight) {
                        ForEach(0..<ranked.count, id: \.self) { i in
                            Text("#\(i + 1) \(urls[ranked[i].sourceIndex].lastPathComponent)").tag(i)
                        }
                    }
                }
                HStack(spacing: 8) {
                    if ranked.count >= 2 {
                        ScrollView([.horizontal, .vertical]) {
                            PreviewImage(url: urls[ranked[compareLeft].sourceIndex],
                                         size: CGFloat(440 * compareZoom))
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        ScrollView([.horizontal, .vertical]) {
                            PreviewImage(url: urls[ranked[compareRight].sourceIndex],
                                         size: CGFloat(440 * compareZoom))
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                HStack {
                    Text(L.text("Масштаб", "Zoom"))
                    Slider(value: $compareZoom, in: 1...3, step: 0.25).frame(width: 250)
                    Text("\(Int(compareZoom * 100))%").monospacedDigit()
                    Spacer()
                    Button(L.text("Закрыть", "Close")) { compare = false }
                }
            }.padding().frame(minWidth: 970, minHeight: 610)
        }
        .alert(L.text("BestShot", "BestShot"), isPresented: Binding(
            get: { alert != nil }, set: { if !$0 { alert = nil } }
        )) { Button("OK") { alert = nil } } message: { Text(alert ?? "") }
    }

    private func explain(_ rank: RankedPhoto) -> String {
        var parts: [String] = []
        for reason in rank.reasons {
            switch reason {
            case "sharp": parts.append(L.text("Хорошая резкость", "Sharper image"))
            case "exposure": parts.append(L.text("Без сильной потери светов и теней", "Limited highlight/shadow clipping"))
            case "face-capture": parts.append(L.text("Учтено качество одного лица", "Single-face capture quality"))
            case "no-faces": parts.append(L.text("Лица не обнаружены", "No faces detected"))
            case "face-count-varies": parts.append(L.text("Число найденных лиц различается", "Detected face counts differ"))
            default: break
            }
        }
        return parts.isEmpty ? L.text("Техническая оценка", "Technical score") : parts.joined(separator: " · ")
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK { start(urls: panel.urls) }
    }

    private func start(urls proposed: [URL]) {
        let unique = Array(NSOrderedSet(array: proposed)) .compactMap { $0 as? URL }
        guard (2...30).contains(unique.count) else {
            alert = L.text("Выберите от 2 до 30 разных фотографий.", "Select 2-30 distinct photos.")
            return
        }
        active?.cancel()
        analysisGeneration &+= 1
        let ticket = analysisGeneration
        urls = unique; processed = 0; results = []; ranked = []; selected = []
        compareLeft = 0; compareRight = 1; compareZoom = 1
        active = Task {
            var output: [PhotoAnalysis] = []
            for (index, url) in unique.enumerated() {
                if Task.isCancelled || ticket != analysisGeneration { break }
                let analysisTask = Task.detached(priority: .userInitiated) {
                    PhotoAnalyzer.analyze(url, index: index)
                }
                let item = await withTaskCancellationHandler {
                    await analysisTask.value
                } onCancel: {
                    analysisTask.cancel()
                }
                if Task.isCancelled || ticket != analysisGeneration { break }
                output.append(item)
                processed += 1
            }
            if !Task.isCancelled && ticket == analysisGeneration {
                results = output
                ranked = Ranker.rank(output.compactMap(\.signals))
                selected = Set(ranked.prefix(3).map(\.sourceIndex))
                if ranked.count < 2 {
                    alert = L.text("Недостаточно обработанных фотографий.",
                                   "Fewer than two images could be analyzed.")
                }
            }
            if ticket == analysisGeneration { active = nil }
        }
    }

    private func export() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        let folderAccess = directory.startAccessingSecurityScopedResource()
        defer { if folderAccess { directory.stopAccessingSecurityScopedResource() } }
        do {
            let copies = try LosslessExporter.copy(selected.sorted().map { urls[$0] },
                                                   into: directory)
            alert = L.text("Экспортировано: \(copies.count). Оригиналы не изменены.",
                           "Exported: \(copies.count). Originals unchanged.")
        } catch let failure as ExportFailure {
            alert = L.text("Экспортировано: \(failure.completed.count). Ошибка: \(failure.underlying.localizedDescription)",
                           "Exported: \(failure.completed.count). Error: \(failure.underlying.localizedDescription)")
        } catch {
            alert = L.text("Ошибка экспорта: \(error.localizedDescription)",
                           "Export error: \(error.localizedDescription)")
        }
    }
}

private struct PreviewImage: View {
    let url: URL
    let size: CGFloat
    @State private var preview: NSImage?

    private var cacheKey: String {
        url.absoluteString + "|" + String(Int(size * 2))
    }

    var body: some View {
        Group {
            if let preview {
                Image(nsImage: preview).resizable().scaledToFit()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: size, maxHeight: size)
        .task(id: cacheKey) {
            // Image decoding used to happen synchronously inside body, and was
            // repeated for every UI state change. Keep heavyweight work off-main.
            preview = nil
            let fileURL = url
            let edge = max(1, Int(size * 2))
            let worker = Task.detached(priority: .utility) { () -> Data? in
                guard !Task.isCancelled else { return nil }
                let scoped = fileURL.startAccessingSecurityScopedResource()
                defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
                guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: edge
                      ] as CFDictionary),
                      !Task.isCancelled,
                      let encoded = CFDataCreateMutable(kCFAllocatorDefault, 0),
                      let destination = CGImageDestinationCreateWithData(
                        encoded, UTType.png.identifier as CFString, 1, nil)
                else { return nil }
                CGImageDestinationAddImage(destination, thumbnail, nil)
                guard CGImageDestinationFinalize(destination), !Task.isCancelled else {
                    return nil
                }
                return encoded as Data
            }
            let data = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            if !Task.isCancelled, let data {
                preview = NSImage(data: data)
            }
        }
    }
}

private final class FileDropCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [(Int, URL)] = []

    func append(_ url: URL, index: Int) {
        lock.lock()
        items.append((index, url))
        lock.unlock()
    }

    func snapshot() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return items.sorted { $0.0 < $1.0 }.map(\.1)
    }
}

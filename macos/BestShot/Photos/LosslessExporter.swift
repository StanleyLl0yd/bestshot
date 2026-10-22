import Foundation

struct ExportFailure: Error {
    let completed: [URL]
    let failedSource: URL
    let underlying: Error
}

/// Byte-for-byte file copies. Never replace, delete, transcode or modify input files.
enum LosslessExporter {
    static func copy(_ sources: [URL], into directory: URL) throws -> [URL] {
        let manager = FileManager.default
        var completed: [URL] = []
        for source in sources {
            #if os(macOS)
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            #endif
            do {
                let attrs = try manager.attributesOfItem(atPath: source.path)
                guard attrs[.type] as? FileAttributeType == .typeRegular else {
                    throw NSError(domain: "BestShot", code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "Only regular files can be exported"])
                }
                let ext = source.pathExtension
                let name = source.deletingPathExtension().lastPathComponent
                var candidate = directory.appendingPathComponent(source.lastPathComponent)
                var suffix = 1
                while manager.fileExists(atPath: candidate.path) {
                    let proposed = name + "-" + String(suffix)
                    candidate = directory.appendingPathComponent(
                        ext.isEmpty ? proposed : proposed + "." + ext)
                    suffix += 1
                }
                try manager.copyItem(at: source, to: candidate)
                completed.append(candidate)
            } catch {
                throw ExportFailure(completed: completed,
                                    failedSource: source, underlying: error)
            }
        }
        return completed
    }
}

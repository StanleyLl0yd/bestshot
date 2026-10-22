import Foundation
import Vision
import ImageIO
import CoreGraphics

struct PhotoAnalysis: Sendable {
    let sourceIndex: Int
    let url: URL
    let signals: PhotoSignals?
    let error: String?
}

enum PhotoAnalyzer {
    static func analyze(_ url: URL, index: Int) -> PhotoAnalysis {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try Task.checkCancellation()
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  CGImageSourceGetCount(source) > 0 else {
                throw NSError(domain: "BestShot", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Unreadable image"])
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1200
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw NSError(domain: "BestShot", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Cannot decode image"])
            }
            try Task.checkCancellation()
            let request = VNDetectFaceCaptureQualityRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            // Face detection failure cannot invalidate valid technical measurements.
            let faces: [VNFaceObservation]
            do {
                try handler.perform([request])
                faces = request.results ?? []
            } catch {
                faces = []
            }
            try Task.checkCancellation()
            let metrics = ImageMetrics.measure(image)
            let singleQuality = faces.count == 1 ? faces.first?.faceCaptureQuality.map(Double.init) : nil
            return PhotoAnalysis(sourceIndex: index, url: url,
                signals: PhotoSignals(sourceIndex: index,
                    sharpness: metrics.sharpness,
                    exposurePenalty: metrics.exposurePenalty,
                    faceCount: faces.count, faceQuality: singleQuality),
                error: nil)
        } catch {
            return PhotoAnalysis(sourceIndex: index, url: url, signals: nil,
                                 error: error.localizedDescription)
        }
    }
}

import CoreGraphics
import Foundation

enum ImageMetrics {
    static func measure(_ image: CGImage) -> (sharpness: Double, exposurePenalty: Double) {
        let ratio = Double(image.width) / Double(max(1, image.height))
        let width = max(1, min(384, Int(384 * min(1, ratio))))
        let height = max(1, min(384, Int(384 / max(1, ratio))))
        let count = width * height
        var pixels = [UInt8](repeating: 0, count: count)
        let didDraw = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let ctx = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                return false
            }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw, count >= 9 else { return (0, 0.5) }
        var edges: Double = 0
        var edgeCount = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let lap = abs(Int(pixels[i - 1]) + Int(pixels[i + 1]) +
                              Int(pixels[i - width]) + Int(pixels[i + width]) -
                              4 * Int(pixels[i]))
                edges += Double(lap * lap)
                edgeCount += 1
            }
        }
        let dark = pixels.filter { $0 <= 5 }.count
        let light = pixels.filter { $0 >= 250 }.count
        let mean = pixels.reduce(0.0) { $0 + Double($1) } / Double(count)
        let clipPenalty = min(1, Double(dark + light) / Double(count))
        let meanPenalty = max(0, abs(mean / 255 - 0.5) - 0.30) / 0.5
        return (max(0, edges / Double(max(edgeCount, 1))),
                min(1, 0.80 * clipPenalty + 0.20 * meanPenalty))
    }
}

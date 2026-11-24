import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct PhotoItem: Identifiable {
    let id: URL
    var selected = true
    var manualSelection = false
    var preview: NSImage?
    var defects: [String] = []
}

@MainActor
final class PhotoSession: ObservableObject {
    @Published var photos: [PhotoItem] = []
    @Published var status = ""
    @AppStorage("review.blur") var blur = 0.5
    @AppStorage("review.highlights") var highlights = 0.5
    @AppStorage("review.shadows") var shadows = 0.5
    @AppStorage("review.exclude") var exclude = false
    private var analysis: Task<Void, Never>?
    var selected: [URL] { photos.filter(\.selected).map(\.id) }

    func add(_ urls: [URL]) {
        var known = Set(photos.map(\.id))
        var added: [URL] = []
        for url in urls {
            let files = url.hasDirectoryPath ? ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []) : [url]
            for file in files.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                let path = file.standardizedFileURL
                if UTType(filenameExtension: path.pathExtension)?.conforms(to: .image) == true, known.insert(path).inserted {
                    photos.append(PhotoItem(id: path))
                    added.append(path)
                }
            }
        }
        guard !added.isEmpty else { status = String(localized: "No new photos found."); return }
        analyze(onlyPending: true)
    }

    func analyze(onlyPending: Bool = false) {
        analysis?.cancel()
        let pending = photos.indices.filter { !onlyPending || photos[$0].preview == nil }
        let thresholds = (blur, highlights, shadows)
        let automatic = exclude
        analysis = Task {
            for (offset, index) in pending.enumerated() {
                guard !Task.isCancelled else { return }
                status = String(localized: "Analyzing \(offset + 1) / \(pending.count)")
                let url = photos[index].id
                let result = await Task.detached(priority: .utility) { PhotoQuality.evaluate(url, thresholds) }.value
                guard !Task.isCancelled else { return }
                photos[index].preview = result.0.map { NSImage(cgImage: $0, size: .zero) }
                photos[index].defects = result.1
                if !photos[index].manualSelection { photos[index].selected = !automatic || result.1.isEmpty }
            }
            status = String(localized: "Analysis complete.")
        }
    }
}

enum PhotoQuality {
    static func evaluate(_ url: URL, _ tolerance: (Double, Double, Double)) -> (CGImage?, [String]) {
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 256]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return (nil, ["Unreadable"]) }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var energy = 0.0, light = 0, dark = 0
        for i in pixels.indices {
            let p = Int(pixels[i])
            if p >= 250 { light += 1 }
            if p <= 5 { dark += 1 }
            if i >= w && i < pixels.count-w && i % w > 0 && i % w < w-1 {
                let laplacian = 4*p - Int(pixels[i-1]) - Int(pixels[i+1]) - Int(pixels[i-w]) - Int(pixels[i+w])
                energy += Double(laplacian * laplacian)
            }
        }
        let count = Double(pixels.count)
        var defects: [String] = []
        if energy/count < 200 * (1-tolerance.0) { defects.append("Blur") }
        if Double(light)/count > tolerance.1 { defects.append("Highlights") }
        if Double(dark)/count > tolerance.2 { defects.append("Shadows") }
        return (image, defects)
    }
}

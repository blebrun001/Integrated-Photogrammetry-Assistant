import XCTest
import RealityKit
import PDFKit
import Vision
import WebKit
@testable import IPA

final class WorkspaceTests: XCTestCase {
    @MainActor
    func testViewerLoadsLocalOBJAndCalibrationStatus() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".obj")
        try "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let viewer = ViewerViewModel()
        viewer.web.frame = CGRect(x: 0, y: 0, width: 800, height: 500)
        viewer.open(url, automatic: true)
        var message = ""
        for _ in 0..<100 {
            message = (try? await viewer.web.evaluateJavaScript("document.querySelector('#status')?.textContent") as? String) ?? ""
            if message == "Model loaded." { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(message, "Model loaded.", viewer.status)
        let state = try await viewer.web.evaluateJavaScript("document.getElementById('calibration').textContent") as? String
        XCTAssertEqual(state, "Calibrated · Auto Scale")
    }

    @MainActor
    func testReconstructionFromPhotoSelection() async throws {
        guard let path = ProcessInfo.processInfo.environment["IPA_CAPTURE_FIXTURE"] else {
            throw XCTSkip("Set TEST_RUNNER_IPA_CAPTURE_FIXTURE to a photogrammetry image folder.")
        }
        let photos = PhotoSession()
        photos.add([URL(fileURLWithPath: path, isDirectory: true)])
        XCTAssertGreaterThan(photos.photos.count, 10)
        photos.photos[0].selected = false
        let input = photos.selected
        XCTAssertEqual(input.count, photos.photos.count - 1)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var result: URL?
        var failure: String?
        var events = [String]()
        await PhotogrammetryManager.shared.startCapture(photos: input, outputFolder: folder, fileName: "fixture",
            detail: .preview, sampleOrdering: .unordered, featureSensitivity: .normal, exportFormat: "USDZ",
            maskMode: .include, compressImages: false, compressionQuality: 1, onEvent: { events.append($0) },
            onProgressUpdate: { _ in }, onCompletion: { result = $0 }, onError: { failure = $0 })
        XCTAssertNil(failure, events.suffix(5).joined(separator: "\n"))
        let model = try XCTUnwrap(result)
        XCTAssertGreaterThan(try Data(contentsOf: model).count, 100)
        let viewer = ViewerViewModel()
        viewer.open(model)
        for _ in 0..<200 {
            let status = try? await viewer.web.evaluateJavaScript("document.getElementById('status').textContent") as? String
            if status == "Model loaded." { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Generated USDZ did not open in the Viewer.")
    }

    func testMarkerCornersInterpolateInsideLargeUVTriangles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".obj")
        defer { try? FileManager.default.removeItem(at: url) }
        try "v 0 0 0\nv 10 0 0\nv 0 10 0\nvt 0 0\nvt 1 0\nvt 0 1\nf 1/1 2/2 3/3\n".write(to: url, atomically: true, encoding: .utf8)
        let corners = [CGPoint(x: 10, y: 20),CGPoint(x: 20, y: 20),CGPoint(x: 20, y: 10),CGPoint(x: 10, y: 10)]
        let result = try OBJMeshAnalyzer().measureDistance(objURL: url, boundingBox: .zero, textureSize: CGSize(width: 100, height: 100), corners: corners)
        XCTAssertEqual(result.distance, sqrt(2), accuracy: 1e-6)
    }

    func testPrintedMarkersUseExpectedPhysicalSizeAndAreRecognizable() throws {
        let document = try XCTUnwrap(PDFDocument(data: MarkerSheet.pdf(sideCM: 2)))
        let page = try XCTUnwrap(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        let image = page.thumbnail(of: NSSize(width: bounds.width*2, height: bounds.height*2), for: .mediaBox)
        let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let options = BarcodeDetector.DetectionOptions(useTiling: false, tileDimension: 0, overlap: 0, deduplicationTolerance: 0)
        let result = try BarcodeDetector().detectBarcodes(in: cg, symbologies: [.microQR], options: options)
        let region = try XCTUnwrap(result.regions.first)
        XCTAssertEqual(region.text, "1")
        XCTAssertEqual(region.boundingBox.width / CGFloat(cg.width) * 21, 2, accuracy: 0.1)
    }
}

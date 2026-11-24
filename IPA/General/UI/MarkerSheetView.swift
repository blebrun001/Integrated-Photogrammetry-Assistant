import SwiftUI
import PDFKit

enum MarkerSheet {
    // ISO Micro QR M1, numeric payload 1. The measured side excludes the quiet zone.
    static let rows = ["11111110101","10000010100","10111010011","10111010100","10111010011","10000010000","11111110011","00000000101","11000100011","01011111101","11111111011"]
    static func pdf(sideCM: Double) -> Data {
        let output = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 210 * 72 / 25.4, height: 297 * 72 / 25.4)
        guard let consumer = CGDataConsumer(data: output), let ctx = CGContext(consumer: consumer, mediaBox: &page, nil) else { return Data() }
        ctx.beginPDFPage(nil)
        ctx.setFillColor(CGColor.white)
        ctx.fill(page)
        ctx.setFillColor(CGColor.black)
        let side = sideCM * 72 / 2.54
        let module = side / Double(rows.count)
        for y in 0..<5 {
            for x in 0..<4 {
                let origin = CGPoint(x: (Double(x)+0.5)*page.width/4-side/2, y: (Double(y)+0.5)*page.height/5-side/2)
                for (r, row) in rows.enumerated() {
                    for (c, bit) in row.enumerated() where bit == "1" {
                        ctx.fill(CGRect(x: origin.x+Double(c)*module, y: origin.y+Double(10-r)*module, width: module, height: module))
                    }
                }
            }
        }
        ctx.endPDFPage()
        ctx.closePDF()
        return output as Data
    }
}

struct MarkerSheetView: View {
    @State private var side = 1.0
    @State private var error = ""
    var body: some View {
        Form {
            Picker("Marker side (cm)", selection: $side) {
                ForEach([0.5,1,2,3], id: \.self) { value in Text("\(value.formatted()) cm").tag(value) }
            }
            Text("Print on A4 at 100%. Disable fit to page. Measure the printed symbol before capture.")
            HStack {
                Button("Export PDF…") {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.pdf]
                    panel.nameFieldStringValue = "IPA-MicroQR-\(side)cm.pdf"
                    if panel.runModal() == .OK, let url = panel.url {
                        do { try MarkerSheet.pdf(sideCM: side).write(to: url, options: .atomic) }
                        catch { self.error = error.localizedDescription }
                    }
                }
                .accessibilityIdentifier("markers.export")
                Button("Print…") {
                    let document = PDFDocument(data: MarkerSheet.pdf(sideCM: side))
                    document?.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleNone, autoRotate: false)?.run()
                }
            }
            Text(error)
        }.padding()
    }
}

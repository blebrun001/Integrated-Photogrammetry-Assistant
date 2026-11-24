import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct ViewerTabView: View {
    @ObservedObject var model: ViewerViewModel
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("Open model…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = ViewerViewModel.formats.compactMap { UTType(filenameExtension: $0) }
                    if panel.runModal() == .OK, let url = panel.url { model.open(url) }
                }
                .accessibilityIdentifier("viewer.open")
                Text(model.source?.lastPathComponent ?? "").font(.headline)
                Spacer()
                Text(model.status).font(.caption)
            }.padding(.horizontal)
            ViewerSurface(web: model.web)
        }.padding(.top, 8)
    }
}

private struct ViewerSurface: NSViewRepresentable {
    let web: WKWebView
    func makeNSView(context: Context) -> WKWebView { web }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

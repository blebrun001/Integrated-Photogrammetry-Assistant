import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct ViewerTabView: View {
    @ObservedObject var model: ViewerViewModel
    var body: some View {
        if let source = model.source {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label(source.lastPathComponent, systemImage: "cube")
                        .font(.headline).lineLimit(1).truncationMode(.middle).help(source.path)
                    Spacer()
                    if !model.status.isEmpty {
                        Text(model.status).font(.callout).foregroundStyle(.secondary)
                            .lineLimit(2).textSelection(.enabled)
                    }
                    openButton
                }.padding(.horizontal, 18).padding(.vertical, 10)
                Divider()
                ViewerSurface(web: model.web)
            }
        } else {
            WorkspacePlaceholder(
                symbol: "view.3d",
                title: "Open a 3D model to begin.",
                detail: Text(verbatim: ViewerViewModel.formats.map { $0.uppercased() }.joined(separator: " · "))
            ) {
                openButton.buttonStyle(.borderedProminent)
            }
            .padding(22)
        }
    }

    private var openButton: some View {
        Button("Open model…", systemImage: "folder") {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = ViewerViewModel.formats.compactMap { UTType(filenameExtension: $0) }
            if panel.runModal() == .OK, let url = panel.url { model.open(url) }
        }
        .accessibilityIdentifier("viewer.open")
    }
}

private struct ViewerSurface: NSViewRepresentable {
    let web: WKWebView
    func makeNSView(context: Context) -> WKWebView { web }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

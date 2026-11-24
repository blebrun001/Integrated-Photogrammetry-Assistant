import WebKit
import SwiftUI
import UniformTypeIdentifiers

/// Only serves the built-in viewer and model resources inside the chosen directory.
final class ViewerResources: NSObject, WKURLSchemeHandler {
    var source: URL?
    var key = UUID().uuidString
    private var promptedKey: String?
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        do {
            guard let url = task.request.url, url.host == "local" else { throw URLError(.badURL) }
            let parts = url.pathComponents.dropFirst()
            let file: URL
            if parts.count == 1, ["viewer.html", "viewer.js"].contains(parts.first),
               let asset = Bundle.main.url(forResource: parts.first, withExtension: nil) { file = asset }
            else {
                guard parts.first == key, let source else { throw URLError(.fileDoesNotExist) }
                let base = source.deletingLastPathComponent().resolvingSymlinksInPath()
                file = base.appendingPathComponent(parts.dropFirst().joined(separator: "/")).standardizedFileURL.resolvingSymlinksInPath()
                guard file.path.hasPrefix(base.path + "/") else { throw URLError(.noPermissionsToReadFile) }
            }
            let data: Data
            do { data = try Data(contentsOf: file, options: .mappedIfSafe) }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoPermissionError && promptedKey != key {
                promptedKey = key
                guard let folder = source?.deletingLastPathComponent(), Self.grantFolder(folder) else { throw error }
                data = try Data(contentsOf: file, options: .mappedIfSafe)
            }
            let mime = file.pathExtension == "js" ? "text/javascript" : UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data)
            task.didFinish()
        } catch { task.didFailWithError(error) }
    }
    static func grantFolder(_ folder: URL) -> Bool {
        let panel = NSOpenPanel()
        panel.directoryURL = folder
        panel.message = "Choose the model folder to allow access to its companion files."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        return panel.runModal() == .OK && panel.url?.standardizedFileURL == folder.standardizedFileURL
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

@MainActor
final class ViewerViewModel: NSObject, ObservableObject, WKScriptMessageHandlerWithReply {
    static let formats = ["obj","glb","gltf","ply","stl","usdz","3mf"]
    let resources = ViewerResources()
    let web: WKWebView
    @Published var source: URL?
    @Published var status = ""
    private var ready = false
    private var automatic = false

    override init() {
        let config = WKWebViewConfiguration()
        let language = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "en"
        if let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language),
           let strings = NSDictionary(contentsOfFile: path),
           let data = try? JSONSerialization.data(withJSONObject: strings),
           let json = String(data: data, encoding: .utf8) {
            let script = WKUserScript(source: "window.ipaStrings = " + json, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            config.userContentController.addUserScript(script)
        }
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(resources, forURLScheme: "ipaasset")
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "ipa")
        web.load(URLRequest(url: URL(string: "ipaasset://local/viewer.html")!))
    }

    func open(_ url: URL, automatic: Bool = false) {
        source = url
        self.automatic = automatic
        resources.source = url
        resources.key = UUID().uuidString
        load()
    }

    private func load() {
        guard ready, let source else { return }
        let path = URL(string: "ipaasset://local")!.appendingPathComponent(resources.key).appendingPathComponent(source.lastPathComponent)
        let arguments: [String: Any] = ["path": path.absoluteString, "calibrated": automatic]
        Task {
            do {
                _ = try await web.callAsyncJavaScript("await window.ipaOpen(path, calibrated)", arguments: arguments, in: nil, contentWorld: .page)
            } catch { status = error.localizedDescription }
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.host == "local",
              let info = message.body as? [String: Any], let action = info["action"] as? String else { replyHandler(nil, "Invalid viewer request"); return }
        if action == "ready" { ready = true; replyHandler(true, nil); load(); return }
        if action == "confirm" {
            let alert = NSAlert()
            alert.messageText = info["text"] as? String ?? ""
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            replyHandler(alert.runModal() == .alertFirstButtonReturn, nil)
            return
        }
        guard action == "save", let source, let ext = info["ext"] as? String,
              (Self.formats + ["png"]).contains(ext), let payload = info["data"] as? String, let data = Data(base64Encoded: payload), !data.isEmpty else { replyHandler(nil, "Invalid export"); return }
        let panel = NSSavePanel()
        panel.directoryURL = source.deletingLastPathComponent()
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + "-edited." + ext
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .data]
        guard panel.runModal() == .OK, let destination = panel.url else { replyHandler(false, nil); return }
        var created: [URL] = []
        do {
            for (name, encoded) in info["assets"] as? [String: String] ?? [:] {
                guard name == URL(fileURLWithPath: name).lastPathComponent, name.hasPrefix("ipa-"), let bytes = Data(base64Encoded: encoded) else { throw CocoaError(.fileWriteInvalidFileName) }
                let url = destination.deletingLastPathComponent().appendingPathComponent(name)
                do { try bytes.write(to: url, options: .withoutOverwriting) }
                catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
                    guard ViewerResources.grantFolder(destination.deletingLastPathComponent()) else { throw error }
                    try bytes.write(to: url, options: .withoutOverwriting)
                }
                created.append(url)
            }
            try data.write(to: destination, options: .atomic)
            status = destination.lastPathComponent
            replyHandler(true, nil)
        } catch {
            for url in created { try? FileManager.default.removeItem(at: url) }
            replyHandler(nil, error.localizedDescription)
        }
    }
}

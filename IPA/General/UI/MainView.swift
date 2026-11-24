import SwiftUI

extension Notification.Name {
    static let openDataverseUpload = Notification.Name("IPA.OpenDataverseUpload")
    static let openModel = Notification.Name("IPA.OpenModel")
    static let autoScaledModel = Notification.Name("IPA.AutoScaledModel")
}

struct MainView: View {
    enum Step: String, CaseIterable { case photos = "Photos", review = "Review", capture = "Reconstruction", viewer = "Viewer", scale = "Auto Scale", tools = "Tools" }
    enum Tool: String, CaseIterable {
        case rename = "OBJ Renamer", structure = "Folder Structure", bone = "Bone Folder", readme = "README Generator", upload = "Dataverse Upload", markers = "Print QR markers"
    }
    @State private var step = Step.photos
    @State private var tool = Tool.rename
    @StateObject private var photos = PhotoSession()
    @StateObject private var viewer = ViewerViewModel()
    @EnvironmentObject var capture: PhotogrammetryViewModel
    @EnvironmentObject var scale: AutoScaleViewModel
    @EnvironmentObject var renamer: OBJRenamerViewModel
    @EnvironmentObject var readme: ReadmeGeneratorViewModel
    @EnvironmentObject var folders: FolderStructureViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(Step.allCases, id: \.self) { item in
                    Button { step = item } label: { Text(LocalizedStringKey(item.rawValue)) }
                        .buttonStyle(.bordered).tint(item == step ? .accentColor : .secondary)
                        .disabled((item == .review && photos.photos.isEmpty) || (item == .capture && photos.selected.isEmpty && !capture.isProcessing) || (item == .scale && scale.objURL == nil && viewer.source?.pathExtension.lowercased() != "obj"))
                }
                Spacer()
                LanguageMenuButton()
            }.padding(10)
            Divider()
            switch step {
            case .photos, .review:
                PhotoReview(session: photos, review: step == .review) { step = step == .review ? .capture : .review }
            case .capture:
                PhotogrammetryTabView(viewModel: capture).environmentObject(photos)
            case .viewer: ViewerTabView(model: viewer)
            case .scale: AutoScaleTabView()
            case .tools:
                HStack(spacing: 0) {
                    List(Tool.allCases, id: \.self, selection: $tool) { entry in Text(LocalizedStringKey(entry.rawValue)).tag(entry) }.frame(width: 170)
                    Divider()
                    Group {
                        switch tool {
                        case .rename: OBJRenameTabView()
                        case .structure: FolderStructureTabView()
                        case .bone: BoneFolderTabView()
                        case .readme: ReadmeGeneratorTabView()
                        case .upload: DataverseUploadTabView(suggestedFile: viewer.source)
                        case .markers: MarkerSheetView()
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }.frame(minWidth: 920, minHeight: 650)
        .onReceive(NotificationCenter.default.publisher(for: .openDataverseUpload)) { _ in tool = .upload; step = .tools }
        .onReceive(NotificationCenter.default.publisher(for: .openModel)) { note in open(note, automatic: false) }
        .onReceive(NotificationCenter.default.publisher(for: .autoScaledModel)) { note in open(note, automatic: true) }
        .onChange(of: viewer.source) {
            guard let url = viewer.source else { return }
            if url.pathExtension.lowercased() == "obj" { scale.setOBJ(url: url) }
            else { scale.objURL = nil }
            let folder = url.deletingLastPathComponent()
            renamer.folder = folder
            readme.folder = folder
            folders.baseDir = folder
        }
        .onChange(of: photos.photos.first?.id) {
            if let folder = photos.photos.first?.id.deletingLastPathComponent() {
                capture.mainFolder = folder
                if folders.baseDir == nil { folders.baseDir = folder }
                if readme.folder == nil { readme.folder = folder }
            }
        }
    }

    private func open(_ note: Notification, automatic: Bool) {
        if let url = note.object as? URL { viewer.open(url, automatic: automatic); step = .viewer }
    }
}

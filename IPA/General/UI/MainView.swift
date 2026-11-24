import SwiftUI

extension Notification.Name {
    static let openDataverseUpload = Notification.Name("IPA.OpenDataverseUpload")
    static let openModel = Notification.Name("IPA.OpenModel")
    static let autoScaledModel = Notification.Name("IPA.AutoScaledModel")
}

struct MainView: View {
    enum Step: String, CaseIterable {
        case photos = "Photos", capture = "Reconstruction"
        case manualScale = "Manual Scale", scale = "Auto Scale", tools = "Tools"

        var symbol: String {
            switch self {
            case .photos: "photo.stack"
            case .capture: "cube.transparent"
            case .manualScale: "ruler"
            case .scale: "qrcode.viewfinder"
            case .tools: "wrench.and.screwdriver"
            }
        }
    }
    enum Tool: String, CaseIterable {
        case rename = "OBJ Renamer", structure = "Folder Structure", bone = "Bone Folder", readme = "README Generator", upload = "Dataverse Upload", markers = "Print QR markers"
    }
    @State private var step = Step.photos
    @State private var tool = Tool.rename
    @State private var showViewer = true
    @StateObject private var photos = PhotoSession()
    @StateObject private var viewer = ViewerViewModel()
    @EnvironmentObject var capture: PhotogrammetryViewModel
    @EnvironmentObject var scale: AutoScaleViewModel
    @EnvironmentObject var renamer: OBJRenamerViewModel
    @EnvironmentObject var readme: ReadmeGeneratorViewModel
    @EnvironmentObject var folders: FolderStructureViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Menu {
                    ForEach(ViewerViewModel.formats, id: \.self) { format in
                        Button(format.uppercased()) { viewer.export(format: format) }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewer.source == nil)
                .accessibilityIdentifier("viewer.export")
                Divider().frame(height: 20).padding(.horizontal, 6)
                ForEach(Step.allCases, id: \.self) { item in
                    let requirement = prerequisite(for: item)
                    Button { step = item } label: {
                        Label(LocalizedStringKey(item.rawValue), systemImage: item.symbol)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(WorkspaceTabStyle(selected: item == step))
                    .accessibilityAddTraits(item == step ? .isSelected : [])
                    .disabled(requirement != nil)
                    .help(requirement ?? LocalizedStringKey(item.rawValue))
                }
                Spacer(minLength: 6)
                Divider().frame(height: 20)
                LanguageMenuButton().fixedSize().padding(.leading, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
            Divider()
            workspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 920, minHeight: 650)
        .inspector(isPresented: $showViewer) {
            ViewerTabView(model: viewer)
                .inspectorColumnWidth(min: 450, ideal: 680, max: 1000)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showViewer.toggle() } label: {
                    Label("Viewer", systemImage: "sidebar.right")
                }
                .accessibilityIdentifier("viewer.toggle")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDataverseUpload)) { _ in tool = .upload; step = .tools }
        .onReceive(NotificationCenter.default.publisher(for: .openModel)) { note in open(note, automatic: false) }
        .onReceive(NotificationCenter.default.publisher(for: .autoScaledModel)) { note in open(note, automatic: true) }
        .onChange(of: step) {
            let manual = step == .manualScale
            if manual { showViewer = true }
            viewer.setManualMode(manual)
        }
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

    @ViewBuilder
    private var workspace: some View {
            switch step {
            case .photos:
                PhotoReview(session: photos)
            case .capture:
                PhotogrammetryTabView(viewModel: capture).environmentObject(photos)
            case .manualScale: ManualScaleView(model: viewer)
            case .scale: AutoScaleTabView()
            case .tools:
                VStack(alignment: .leading, spacing: 0) {
                    Picker("Tools", selection: $tool) {
                        ForEach(Tool.allCases, id: \.self) { entry in
                            Text(LocalizedStringKey(entry.rawValue)).tag(entry)
                        }
                    }
                    .labelsHidden()
                    .padding(12)
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
    }

    private func prerequisite(for step: Step) -> LocalizedStringKey? {
        switch step {
        case .capture where !capture.isProcessing && !photos.photos.contains(where: \.selected):
            "Select photos for reconstruction."
        case .scale where scale.objURL == nil && viewer.source?.pathExtension.lowercased() != "obj":
            "Open an OBJ model to use automatic scaling."
        default: nil
        }
    }

    private func open(_ note: Notification, automatic: Bool) {
        if let url = note.object as? URL {
            viewer.open(url, automatic: automatic)
            showViewer = true
        }
    }
}

private struct WorkspaceTabStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: selected ? .semibold : .regular))
            .padding(.horizontal, 9)
            .frame(height: 34)
            .foregroundStyle(enabled ? Color.primary : Color(nsColor: .disabledControlTextColor))
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(selected ? Color.accentColor.opacity(0.15)
                          : Color.primary.opacity(enabled && (hovering || configuration.isPressed) ? 0.08 : 0))
            }
            .overlay(alignment: .bottom) {
                if selected {
                    Capsule().fill(Color.accentColor).frame(width: 20, height: 3)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

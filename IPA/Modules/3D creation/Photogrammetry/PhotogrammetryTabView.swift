//  PhotogrammetryTabView.swift
//  View for launching and configuring photogrammetry 3D model generation.

import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct PhotogrammetryTabView: View {
    
    @EnvironmentObject var settings: SettingsManager
    
    @ObservedObject var viewModel: PhotogrammetryViewModel
    @EnvironmentObject var photos: PhotoSession
    private let photogrammetry = PhotogrammetryManager.shared

    // Available export formats
    enum ExportFormat: String, CaseIterable {
        case usdz = "USDZ", obj = "OBJ"
    }

    // Texture compression levels
    enum TextureCompressionLevel: String, CaseIterable, Identifiable {
        case none, low, medium, high

        var id: Self { self }

        var localizedName: LocalizedStringKey {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
    
    // Error alert state
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Parameters and export options
            HStack {
                (Text(NSLocalizedString("3D model name", comment: "Label for 3D model name field")) + Text(":"))
                TextField(NSLocalizedString("3D model name", comment: "Placeholder for 3D model name field"), text: $viewModel.fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            HStack {
                Picker(NSLocalizedString("Export format", comment: "Picker label for export format"), selection: $viewModel.exportFormat) {
                    Text(NSLocalizedString("USDZ", comment: "Export format USDZ" )).tag(ExportFormat.usdz)
                    Text(NSLocalizedString("OBJ", comment: "Export format OBJ" )).tag(ExportFormat.obj)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker(NSLocalizedString("Detail level", comment: "Picker label for detail level"), selection: $viewModel.detail) {
                    Text(NSLocalizedString("Preview", comment: "Detail level preview" )).tag(PhotogrammetrySession.Request.Detail.preview)
                    Text(NSLocalizedString("Reduced", comment: "Detail level reduced" )).tag(PhotogrammetrySession.Request.Detail.reduced)
                    Text(NSLocalizedString("Medium", comment: "Detail level medium" )).tag(PhotogrammetrySession.Request.Detail.medium)
                    Text(NSLocalizedString("Full", comment: "Detail level full" )).tag(PhotogrammetrySession.Request.Detail.full)
                    Text(NSLocalizedString("Raw", comment: "Detail level raw" )).tag(PhotogrammetrySession.Request.Detail.raw)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker(NSLocalizedString("Photos order", comment: "Picker label for photos ordering"), selection: $viewModel.sampleOrdering) {
                    Text(NSLocalizedString("Unordered", comment: "Sample ordering unordered" )).tag(PhotogrammetrySession.Configuration.SampleOrdering.unordered)
                    Text(NSLocalizedString("Sequential", comment: "Sample ordering sequential" )).tag(PhotogrammetrySession.Configuration.SampleOrdering.sequential)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker(NSLocalizedString("Sensitivity:", comment: "Picker label for feature sensitivity"), selection: $viewModel.featureSensitivity) {
                    Text(NSLocalizedString("Normal", comment: "Feature sensitivity normal" )).tag(PhotogrammetrySession.Configuration.FeatureSensitivity.normal)
                    Text(NSLocalizedString("High", comment: "Feature sensitivity high" )).tag(PhotogrammetrySession.Configuration.FeatureSensitivity.high)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            HStack {
                Picker(NSLocalizedString("Mask:", comment: "Picker label for mask mode"), selection: $viewModel.maskMode) {
                    Text(NSLocalizedString("Isolate from environment", comment: "Mask option isolate from environment" )).tag(PhotogrammetryManager.MaskMode.isolate)
                    Text(NSLocalizedString("Include environment", comment: "Mask option include environment" )).tag(PhotogrammetryManager.MaskMode.include)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            HStack {
                Picker(NSLocalizedString("Texture compression:", comment: "Picker label for texture compression"), selection: $viewModel.textureCompressionLevel) {
                    ForEach(TextureCompressionLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // File cleanup options after export
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(NSLocalizedString("Files to delete after export", comment: "Label for cleanup toggles"))

                Toggle(NSLocalizedString("USDA", comment: "Toggle label for deleting USDA files"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteUSDAFiles },
                    set: { PhotogrammetryManager.shared.shouldDeleteUSDAFiles = $0 }
                ))
                Toggle(NSLocalizedString("AO", comment: "Toggle label for deleting ambient occlusion files"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteAO },
                    set: { PhotogrammetryManager.shared.shouldDeleteAO = $0 }
                ))
                Toggle(NSLocalizedString("Displacement", comment: "Toggle label for deleting displacement maps"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteDisplacement },
                    set: { PhotogrammetryManager.shared.shouldDeleteDisplacement = $0 }
                ))
                Toggle(NSLocalizedString("Normal", comment: "Toggle label for deleting normal maps"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteNormal },
                    set: { PhotogrammetryManager.shared.shouldDeleteNormal = $0 }
                ))
                Toggle(NSLocalizedString("Roughness", comment: "Toggle label for deleting roughness maps"), isOn: Binding(
                    get: { PhotogrammetryManager.shared.shouldDeleteRoughness },
                    set: { PhotogrammetryManager.shared.shouldDeleteRoughness = $0 }
                ))
            }.frame(maxWidth: .infinity, alignment: .leading)
            
            // Capture controls
            HStack(spacing: 20) {
                Button(NSLocalizedString("Start", comment: "Button to start photogrammetry")) {
                    if settings.enableSound {
                        SoundPlayer.playSound(named: "start_capture")
                    }
                    startCapture()
                }
                    .disabled(viewModel.isProcessing)
                
                Button(NSLocalizedString("Stop", comment: "Button to stop photogrammetry")) {
                    if settings.enableSound {
                        SoundPlayer.playSound(named: "stop_capture")
                    }
                    photogrammetry.stopCapture()
                    viewModel.statusMessage = NSLocalizedString("Process stopped by user.", comment: "Status when user stops photogrammetry")
                }
                .disabled(!viewModel.isProcessing)
            }

            // Progress feedback
            if viewModel.isProcessing {
                VStack(spacing: 20) {
                    HStack {
                        ProgressView(value: viewModel.progress)
                            .frame(width: 300)
                        Text(String(format: NSLocalizedString("%lld%%", comment: "Progress percentage"), Int64(viewModel.progress * 100)))
                            .frame(width: 50, alignment: .leading)
                    }
                    
                    AnimatedLoader()
                        .frame(width: 30, height: 30)
                        .padding(.top, 1)
                        .opacity(1)
                }
            }

            // Status message
            Text(viewModel.statusMessage)
                .foregroundColor(.blue)
                .padding(.top, 10)

            ScrollView { Text(viewModel.log.joined(separator: "\n")).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(NSLocalizedString("Error", comment: "Generic error title"), isPresented: $showErrorAlert) {
            Button(NSLocalizedString("OK", comment: "Dismiss error alert"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startCapture() {
        let input = photos.selected
        let name = viewModel.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            viewModel.statusMessage = "Select photos and enter a valid model name."
            return
        }
        let panel = NSOpenPanel()
        panel.prompt = "Choose output folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let output = panel.url else { return }
        viewModel.log = []
        viewModel.savePreferences()
        viewModel.isProcessing = true
        viewModel.progress = 0.0
        viewModel.statusMessage = NSLocalizedString("Processing", comment: "Status while photogrammetry is running")
        viewModel.startTime = Date()
        
        Task {
            await photogrammetry.startCapture(
                photos: input,
                outputFolder: output,
                fileName: name,
                detail: viewModel.detail,
                sampleOrdering: viewModel.sampleOrdering,
                featureSensitivity: viewModel.featureSensitivity,
                exportFormat: viewModel.exportFormat.rawValue,
                maskMode: viewModel.maskMode,
                compressImages: viewModel.textureCompressionLevel != .none,
                compressionQuality: compressionQualityValue(for: viewModel.textureCompressionLevel),
                onEvent: { event in DispatchQueue.main.async { viewModel.log.append(event) } },
                onProgressUpdate: { newProgress in
                    DispatchQueue.main.async { self.viewModel.progress = newProgress }
                },
                onCompletion: { fileURL in
                    DispatchQueue.main.async {
                        self.viewModel.isProcessing = false
                        NotificationCenter.default.post(name: .openModel, object: fileURL)
                        let duration = Date().timeIntervalSince(self.viewModel.startTime ?? Date())
                        let durationString = String(format: NSLocalizedString("%.2f", comment: "Two-decimal duration"), duration)
                        let template = NSLocalizedString("Processed in %@ sec. File: %@", comment: "Status after photogrammetry completes")
                        self.viewModel.statusMessage = String(format: template, durationString, fileURL.lastPathComponent)
                    }
                },
                onError: { message in
                    DispatchQueue.main.async {
                        self.viewModel.isProcessing = false
                        self.errorMessage = message
                        self.viewModel.statusMessage = message
                        self.showErrorAlert = true
                    }
                }
            )
        }
    }
    
    // Maps compression level to JPEG compression quality
    private func compressionQualityValue(for level: TextureCompressionLevel) -> CGFloat {
        switch level {
        case .none:   return 1.0
        case .low:    return 0.8
        case .medium: return 0.5
        case .high:   return 0.3
        }
    }
}

// Preview with a sample ViewModel instance
struct PhotogrammetryTabView_Previews: PreviewProvider {
    static var previews: some View {
        // Pour le preview, vous pouvez créer une instance test du view model
        PhotogrammetryTabView(viewModel: PhotogrammetryViewModel())
    }
}

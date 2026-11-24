//  PhotogrammetryTabView.swift
//  View for launching and configuring photogrammetry 3D model generation.

import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct PhotogrammetryTabView: View {
    
    @EnvironmentObject var settings: SettingsManager
    
    @ObservedObject var viewModel: PhotogrammetryViewModel
    @EnvironmentObject var photos: PhotoSession
    @ObservedObject private var photogrammetry = PhotogrammetryManager.shared

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
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Model output") {
                    TextField("3D model name", text: $viewModel.fileName)
                        .textFieldStyle(.roundedBorder)
                    Picker(NSLocalizedString("Export format", comment: "Picker label for export format"), selection: $viewModel.exportFormat) {
                        Text(NSLocalizedString("USDZ", comment: "Export format USDZ" )).tag(ExportFormat.usdz)
                        Text(NSLocalizedString("OBJ", comment: "Export format OBJ" )).tag(ExportFormat.obj)
                    }
                    .pickerStyle(.segmented)
                    Picker(NSLocalizedString("Detail level", comment: "Picker label for detail level"), selection: $viewModel.detail) {
                        Text(NSLocalizedString("Preview", comment: "Detail level preview" )).tag(PhotogrammetrySession.Request.Detail.preview)
                        Text(NSLocalizedString("Reduced", comment: "Detail level reduced" )).tag(PhotogrammetrySession.Request.Detail.reduced)
                        Text(NSLocalizedString("Medium", comment: "Detail level medium" )).tag(PhotogrammetrySession.Request.Detail.medium)
                        Text(NSLocalizedString("Full", comment: "Detail level full" )).tag(PhotogrammetrySession.Request.Detail.full)
                        Text(NSLocalizedString("Raw", comment: "Detail level raw" )).tag(PhotogrammetrySession.Request.Detail.raw)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Reconstruction settings") {
                    Picker(NSLocalizedString("Photos order", comment: "Picker label for photos ordering"), selection: $viewModel.sampleOrdering) {
                        Text(NSLocalizedString("Unordered", comment: "Sample ordering unordered" )).tag(PhotogrammetrySession.Configuration.SampleOrdering.unordered)
                        Text(NSLocalizedString("Sequential", comment: "Sample ordering sequential" )).tag(PhotogrammetrySession.Configuration.SampleOrdering.sequential)
                    }
                    .pickerStyle(.segmented)
                    Picker(NSLocalizedString("Sensitivity:", comment: "Picker label for feature sensitivity"), selection: $viewModel.featureSensitivity) {
                        Text(NSLocalizedString("Normal", comment: "Feature sensitivity normal" )).tag(PhotogrammetrySession.Configuration.FeatureSensitivity.normal)
                        Text(NSLocalizedString("High", comment: "Feature sensitivity high" )).tag(PhotogrammetrySession.Configuration.FeatureSensitivity.high)
                    }
                    .pickerStyle(.segmented)
                    Picker(NSLocalizedString("Mask:", comment: "Picker label for mask mode"), selection: $viewModel.maskMode) {
                        Text(NSLocalizedString("Isolate from environment", comment: "Mask option isolate from environment" )).tag(PhotogrammetryManager.MaskMode.isolate)
                        Text(NSLocalizedString("Include environment", comment: "Mask option include environment" )).tag(PhotogrammetryManager.MaskMode.include)
                    }
                    .pickerStyle(.segmented)
                    Picker(NSLocalizedString("Texture compression:", comment: "Picker label for texture compression"), selection: $viewModel.textureCompressionLevel) {
                        ForEach(TextureCompressionLevel.allCases, id: \.self) { level in
                            Text(level.localizedName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Files to remove from reconstruction") {
                    HStack(spacing: 16) {
                        Toggle("USDA", isOn: $photogrammetry.shouldDeleteUSDAFiles)
                        Toggle("AO", isOn: $photogrammetry.shouldDeleteAO)
                        Toggle("Displacement", isOn: $photogrammetry.shouldDeleteDisplacement)
                        Toggle("Normal", isOn: $photogrammetry.shouldDeleteNormal)
                        Toggle("Roughness", isOn: $photogrammetry.shouldDeleteRoughness)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .formStyle(.grouped)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button("Start", systemImage: "play.fill") {
                        if settings.enableSound { SoundPlayer.playSound(named: "start_capture") }
                        startCapture()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isProcessing)
                    Button("Stop", systemImage: "stop.fill") {
                        if settings.enableSound { SoundPlayer.playSound(named: "stop_capture") }
                        photogrammetry.stopCapture()
                        viewModel.statusMessage = NSLocalizedString("Process stopped by user.", comment: "Stopped capture")
                    }
                    .disabled(!viewModel.isProcessing)
                    if viewModel.isProcessing {
                        ProgressView(value: viewModel.progress).frame(maxWidth: 180)
                        Text(viewModel.progress, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    Spacer()
                    Text("\(photos.selected.count) / \(photos.photos.count) selected")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage).textSelection(.enabled)
                }
                if !viewModel.log.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                Text(viewModel.log.joined(separator: "\n"))
                                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Color.clear.frame(height: 1).id("logEnd")
                            }
                        }
                        .onAppear { proxy.scrollTo("logEnd", anchor: .bottom) }
                        .onChange(of: viewModel.log.count) { proxy.scrollTo("logEnd", anchor: .bottom) }
                    }
                    .frame(height: 84)
                }
            }
            .padding(16)
        }
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
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("IPA-Reconstruction-" + UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return
        }
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
                        try? FileManager.default.removeItem(at: output)
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

//  PhotogrammetryViewModel.swift
//  ViewModel for managing folder selection, capture settings, and progress tracking for photogrammetry.


import SwiftUI
import RealityKit
import UniformTypeIdentifiers

class PhotogrammetryViewModel: ObservableObject {
    
    // Folder selection
    @Published var mainFolder: URL? = nil                   // Root folder containing specimens

    // Capture parameters
    @Published var fileName: String = "model"
    @Published var detail: PhotogrammetrySession.Request.Detail = .full { didSet { savePreferences() } }
    @Published var sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering = .unordered { didSet { savePreferences() } }
    @Published var featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity = .normal { didSet { savePreferences() } }

    // Format and additional options
    @Published var exportFormat: PhotogrammetryTabView.ExportFormat = .obj { didSet { savePreferences() } }
    @Published var maskMode: PhotogrammetryManager.MaskMode = .isolate { didSet { savePreferences() } }
    @Published var textureCompressionLevel: PhotogrammetryTabView.TextureCompressionLevel = .none { didSet { savePreferences() } }

    // Progress tracking
    @Published var progress: Double = 0.0
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = "Select main working folder."
    @Published var startTime: Date? = nil
    
    @Published var log: [String] = []

    private var restoringPreferences = true

    init() {
        let d = UserDefaults.standard
        mainFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let n = d.object(forKey: "capture.detail") as? Int { detail = .init(rawValue: n) ?? .full }
        sampleOrdering = d.bool(forKey: "capture.sequential") ? .sequential : .unordered
        featureSensitivity = d.bool(forKey: "capture.sensitive") ? .high : .normal
        exportFormat = .init(rawValue: d.string(forKey: "capture.format") ?? "") ?? .obj
        maskMode = .init(rawValue: d.string(forKey: "capture.mask") ?? "") ?? .isolate
        textureCompressionLevel = .init(rawValue: d.string(forKey: "capture.compression") ?? "") ?? .none
        restoringPreferences = false
        statusMessage = ""
    }

    func savePreferences() {
        guard !restoringPreferences else { return }
        let d = UserDefaults.standard
        d.set(detail.rawValue, forKey: "capture.detail")
        d.set(sampleOrdering == .sequential, forKey: "capture.sequential")
        d.set(featureSensitivity == .high, forKey: "capture.sensitive")
        d.set(exportFormat.rawValue, forKey: "capture.format")
        d.set(maskMode.rawValue, forKey: "capture.mask")
        d.set(textureCompressionLevel.rawValue, forKey: "capture.compression")
    }
}

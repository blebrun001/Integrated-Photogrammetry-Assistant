//  PhotogrammetryManager.swift
//  Singleton manager that handles photogrammetry sessions, file exports, compression, and cleanup logic.

import Foundation
import SwiftUI
import Combine
import RealityKit
import AppKit

public class PhotogrammetryManager: ObservableObject {
    
    // Shared singleton instance
    static let shared = PhotogrammetryManager()
    
    // Flags for post-processing cleanup
    @AppStorage("capture.shouldDeleteUSDAFiles") var shouldDeleteUSDAFiles = true
    @AppStorage("capture.shouldDeleteAO") var shouldDeleteAO = false
    @AppStorage("capture.shouldDeleteDisplacement") var shouldDeleteDisplacement = false
    @AppStorage("capture.shouldDeleteNormal") var shouldDeleteNormal = false
    @AppStorage("capture.shouldDeleteRoughness") var shouldDeleteRoughness = false


    private var currentSession: PhotogrammetrySession?

    // Enum defining how the masking is handled during export
    public enum MaskMode: String {
        case isolate = "Isolate from environment"
        case include = "Include environment"
    }

    private init() { }  // Prevent multiple instances

    // Launches a photogrammetry session with specified configuration
    @MainActor public func startCapture(photos: [URL], outputFolder: URL, fileName: String,
                             detail: PhotogrammetrySession.Request.Detail,
                             sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering,
                             featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity,
                             exportFormat: String,
                             maskMode: MaskMode,
                             compressImages: Bool,
                             compressionQuality: CGFloat,
                             onEvent: @escaping (String) -> Void,
                             onProgressUpdate: @escaping (Double) -> Void,
                             onCompletion: @escaping (URL) -> Void,
                             onError: @escaping (String) -> Void) async {
        guard PhotogrammetrySession.isSupported else {
            onError("Photogrammetry unsupported by this machine.")
            return
        }
        do {
            var config = PhotogrammetrySession.Configuration()
            config.isObjectMaskingEnabled = maskMode == .isolate
            config.sampleOrdering = sampleOrdering
            config.featureSensitivity = featureSensitivity
            
            let isOBJ = exportFormat == "OBJ"
            let name = isOBJ ? fileName : fileName + ".usdz"
            let destination = outputFolder.appendingPathComponent(name, isDirectory: isOBJ)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                onError(NSLocalizedString("A model with this name already exists.", comment: "Reconstruction output conflict"))
                return
            }
            // Publish only completed output. Keeping staging beside the destination allows a volume-local move.
            let staging = outputFolder.appendingPathComponent(".ipa-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: staging) }
            let outputURL = staging.appendingPathComponent(name, isDirectory: isOBJ)
            if isOBJ { try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: false) }
            let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: detail)

            // RealityKit reads the original files through these per-run links.
            let inputFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: inputFolder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: inputFolder) }
            for (index, url) in photos.enumerated() {
                let name = String(format: "%08d", index) + "." + url.pathExtension
                try FileManager.default.createSymbolicLink(at: inputFolder.appendingPathComponent(name), withDestinationURL: url)
            }
            onEvent("Input: \(photos.count) photos. Output: \(destination.path)")
            let session = try PhotogrammetrySession(input: inputFolder, configuration: config)
            self.currentSession = session
            
            defer { currentSession = nil }
            try session.process(requests: [request])
            for try await output in session.outputs {
                onEvent(String(describing: output))
                switch output {
                case .processingComplete:
                    print("Process complete")

                    await MainActor.run {
                        if SettingsManager.instance.enableSound {
                            SoundPlayer.playSound(named: "success_capture")
                        }
                    }

                    if exportFormat == "OBJ" {
                        let objFolder = outputURL
                        print("Suppression activée, tentative de suppression dans : \(objFolder.path)")
                        deleteFiles(in: objFolder)
                    }
                    if exportFormat == "OBJ" {
                        let objFolder = outputURL
                        var foundOBJ: URL?
                        var waitTime = 0
                        while foundOBJ == nil && waitTime < 10 {
                            let files = try FileManager.default.contentsOfDirectory(at: objFolder, includingPropertiesForKeys: nil)
                            foundOBJ = files.first(where: { $0.pathExtension.lowercased() == "obj" })
                            if foundOBJ == nil {
                                try await Task.sleep(nanoseconds: 500_000_000)
                                waitTime += 1
                            }
                        }

                        if let originalOBJ = foundOBJ {
                            print("OBJ file found: \(originalOBJ.path)")
                            let renamedOBJ = try self.renameExportedAssets(originalOBJ: originalOBJ)
                            if compressImages {
                                do {
                                    try self.compressImages(in: objFolder, quality: compressionQuality)
                                } catch {
                                    print("Compression image error: \(error.localizedDescription)")
                                }
                            }
                            try FileManager.default.moveItem(at: outputURL, to: destination)
                            onCompletion(destination.appendingPathComponent(renamedOBJ.lastPathComponent))
                        } else {
                            print("No OBJ file found in \(objFolder.path)")
                            let msg = NSLocalizedString("No 3D OBJ file was created.", comment: "Error when no OBJ was generated")
                            onError(msg)
                        }
                    } else {
                        // For USDZ, ensure the file exists (allow short delay)
                        var exists = FileManager.default.fileExists(atPath: outputURL.path)
                        var checks = 0
                        while !exists && checks < 10 {
                            try await Task.sleep(nanoseconds: 200_000_000)
                            exists = FileManager.default.fileExists(atPath: outputURL.path)
                            checks += 1
                        }
                        if exists {
                            try FileManager.default.moveItem(at: outputURL, to: destination)
                            onCompletion(destination)
                        } else {
                            let msg = NSLocalizedString("No 3D USDZ file was created.", comment: "Error when no USDZ was generated")
                            onError(msg)
                        }
                    }
                    return
                case .requestError(_, let error):
                    print("Error: \(error.localizedDescription)")
                    onError(error.localizedDescription)
                    return
                case .processingCancelled:
                    onError("Reconstruction cancelled.")
                    return
                case .requestProgress(_, let fractionComplete):
                    DispatchQueue.main.async {
                        onProgressUpdate(fractionComplete)
                    }
                default:
                    break
                }
            }
        } catch {
            print("Session initialization error: \(error.localizedDescription)")
            onError(error.localizedDescription)
        }
    }
    
    // Cancels an active photogrammetry session
    @MainActor public func stopCapture() {
        currentSession?.cancel()
        currentSession = nil
        print("Process stoped by user")
    }

    // Renames exported OBJ/MTL and texture assets to match specimen/bone naming rules
    private func renameExportedAssets(originalOBJ: URL) throws -> URL {
        let fileManager = FileManager.default
        let modelFolder = originalOBJ.deletingLastPathComponent()

        func sanitized(_ name: String) -> String {
            name
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "\t", with: "_")
        }

        let baseName = sanitized(modelFolder.lastPathComponent)

        var objURL = originalOBJ
        var mtlURL: URL?
        var renamedFilenames: [String: String] = [:]

        // Rename OBJ file
        let desiredOBJName = "\(baseName)_model.obj"
        let desiredOBJURL = modelFolder.appendingPathComponent(desiredOBJName)
        if objURL.lastPathComponent != desiredOBJName {
            if fileManager.fileExists(atPath: desiredOBJURL.path) {
                try fileManager.removeItem(at: desiredOBJURL)
            }
            try fileManager.moveItem(at: objURL, to: desiredOBJURL)
            print("OBJ renamed: \(objURL.lastPathComponent) → \(desiredOBJName)")
            objURL = desiredOBJURL
        }

        let files = try fileManager.contentsOfDirectory(at: modelFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

        // Rename MTL file if present
        if let existingMTL = files.first(where: { $0.pathExtension.lowercased() == "mtl" }) {
            let desiredMTLName = "\(baseName)_material.mtl"
            let desiredMTLURL = modelFolder.appendingPathComponent(desiredMTLName)
            if existingMTL.lastPathComponent != desiredMTLName {
                if fileManager.fileExists(atPath: desiredMTLURL.path) {
                    try fileManager.removeItem(at: desiredMTLURL)
                }
                try fileManager.moveItem(at: existingMTL, to: desiredMTLURL)
                print("MTL renamed: \(existingMTL.lastPathComponent) → \(desiredMTLName)")
                renamedFilenames[existingMTL.lastPathComponent] = desiredMTLName
                mtlURL = desiredMTLURL
            } else {
                mtlURL = existingMTL
            }
        }

        // Rename texture maps following requested nomenclature
        let textureExtensions: Set<String> = ["png", "jpg", "jpeg", "tif", "tiff", "bmp", "exr"]
        var typeCounts: [String: Int] = [:]

        func renameTextures(in files: [URL]) throws {
            for file in files {
                let ext = file.pathExtension.lowercased()
                guard textureExtensions.contains(ext) else { continue }

                let lowercased = file.lastPathComponent.lowercased()
                guard let baseType = textureType(for: lowercased) else { continue }

                let usageCount = typeCounts[baseType, default: 0]
                typeCounts[baseType] = usageCount + 1

                let typeSuffix = usageCount == 0 ? baseType : "\(baseType)_\(usageCount + 1)"
                let desiredTextureName = "\(baseName)_\(typeSuffix)." + file.pathExtension
                let desiredTextureURL = file.deletingLastPathComponent().appendingPathComponent(desiredTextureName)

                if file.lastPathComponent != desiredTextureName {
                    if fileManager.fileExists(atPath: desiredTextureURL.path) {
                        try fileManager.removeItem(at: desiredTextureURL)
                    }
                    try fileManager.moveItem(at: file, to: desiredTextureURL)
                    print("Texture renamed: \(file.lastPathComponent) → \(desiredTextureName)")
                    renamedFilenames[file.lastPathComponent] = desiredTextureName
                }
            }
        }

        try renameTextures(in: files)

        let texturesFolder = modelFolder.appendingPathComponent("textures", isDirectory: true)
        if fileManager.directoryExists(at: texturesFolder) {
            let nestedFiles = try fileManager.contentsOfDirectory(at: texturesFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            try renameTextures(in: nestedFiles)
        }

        // Update OBJ mtllib reference if needed
        if let mtlRenameEntry = renamedFilenames.first(where: { $0.key.lowercased().hasSuffix(".mtl") }) {
            let newMtlName = mtlRenameEntry.value
            var objLines = try String(contentsOf: objURL, encoding: .utf8)
                .components(separatedBy: .newlines)
            var updated = false
            for index in objLines.indices {
                let trimmed = objLines[index].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("mtllib ") {
                    objLines[index] = "mtllib \(newMtlName)"
                    updated = true
                    break
                }
            }
            if updated {
                let newContent = objLines.joined(separator: "\n")
                try newContent.write(to: objURL, atomically: true, encoding: .utf8)
            }
        }

        // Update MTL references for renamed textures
        if let effectiveMTLURL = mtlURL ?? files.first(where: { $0.pathExtension.lowercased() == "mtl" }) {
            var mtlContent = try String(contentsOf: effectiveMTLURL, encoding: .utf8)
            for (oldName, newName) in renamedFilenames where !oldName.lowercased().hasSuffix(".mtl") {
                mtlContent = mtlContent.replacingOccurrences(of: oldName, with: newName)
            }
            try mtlContent.write(to: effectiveMTLURL, atomically: true, encoding: .utf8)
        }

        return objURL
    }

    private func textureType(for filename: String) -> String? {
        if filename.contains("tex0") {
            return "texture"
        }
        if filename.contains("roughness0") {
            return "roughness"
        }
        if filename.contains("norm0") {
            return "normal"
        }
        if filename.contains("disp0") {
            return "displacement"
        }
        if filename.contains("ao0") {
            return "ambiant-occlusion"
        }
        return nil
    }

    // Builds a model export request with specified mask mode
    // Compresses texture images in the export folder.
    private func compressImages(in folder: URL, quality: CGFloat) throws {
        let fileManager = FileManager.default
        let imageExtensions: Set<String> = ["png", "tif", "tiff", "bmp", "jpeg", "jpg"]
        let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        var mapping: [String: String] = [:]
        
        for file in files {
            let ext = file.pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                guard let image = NSImage(contentsOf: file) else {
                    print("Can't load photo: \(file.path)")
                    continue
                }
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
                    print("Compression failed: \(file.path)")
                    continue
                }
                if ext == "jpg" || ext == "jpeg" {
                    try jpegData.write(to: file, options: .atomic)
                } else {
                    let newFile = file.deletingPathExtension().appendingPathExtension("jpg")
                    if fileManager.fileExists(atPath: newFile.path) {
                        try fileManager.removeItem(at: newFile)
                    }
                    try jpegData.write(to: newFile, options: .atomic)
                    try fileManager.removeItem(at: file)
                    mapping[file.lastPathComponent] = newFile.lastPathComponent
                }
            }
        }
        
        // Update MTL file with new texture names
        if let mtlFile = files.first(where: { $0.pathExtension.lowercased() == "mtl" }) {
            var mtlContent = try String(contentsOf: mtlFile, encoding: .utf8)
            for (oldName, newName) in mapping {
                mtlContent = mtlContent.replacingOccurrences(of: oldName, with: newName)
            }
            try mtlContent.write(to: mtlFile, atomically: true, encoding: .utf8)
        }
    }
    
    // Deletes unnecessary files after export, based on user settings
    private func deleteFiles(in folder: URL) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            print("Erreur : impossible de lire le contenu de \(folder.path)")
            return
        }

        for file in files {
            let name = file.lastPathComponent.lowercased()
            let ext = file.pathExtension.lowercased()

            if ext == "usda", shouldDeleteUSDAFiles {
                print("Suppression .usda : \(name)")
                try? fileManager.removeItem(at: file)
            } else if (name.contains("ao0") || name.contains("ambiant-occlusion")), shouldDeleteAO {
                print("Suppression Ambient Occlusion : \(name)")
                try? fileManager.removeItem(at: file)
            } else if (name.contains("disp0") || name.contains("displacement")), shouldDeleteDisplacement {
                print("Suppression Displacement : \(name)")
                try? fileManager.removeItem(at: file)
            } else if (name.contains("norm0") || name.contains("_normal")), shouldDeleteNormal {
                print("Suppression Normal Map : \(name)")
                try? fileManager.removeItem(at: file)
            } else if (name.contains("roughness0") || name.contains("roughness")), shouldDeleteRoughness {
                print("Suppression Roughness Map : \(name)")
                try? fileManager.removeItem(at: file)
            }
        }
    }
}

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

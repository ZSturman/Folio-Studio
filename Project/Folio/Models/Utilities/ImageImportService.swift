//
//  ImageImportService.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Centralized service for importing, saving, deleting, and reverting images in Folio documents.
/// Consolidates logic previously duplicated across ImageSlotView and MediaInspectorView.
struct ImageImportService {
    
    /// Result of an image import operation
    struct ImportResult {
        let assetPath: AssetPath
        let error: String?
    }
    
    // MARK: - Select Source Image
    
    /// Shows an NSOpenPanel for the user to select an image file
    /// - Returns: Selected image URL, or nil if cancelled
    static func selectSourceImage() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
    
    // MARK: - Import Image
    
    /// Imports an image for a given label: copies to SourceImages, renders with aspect ratio, saves to edited path
    /// - Parameters:
    ///   - label: The image label (thumbnail, banner, custom, etc.)
    ///   - sourceURL: The source image file URL
    ///   - document: The Folio document binding
    ///   - customAspect: Optional custom aspect ratio (only used for custom labels)
    /// - Returns: ImportResult with the created AssetPath and any error message
    static func importImage(
        label: ImageLabel,
        sourceURL: URL,
        document: Binding<FolioDocument>,
        customAspect: CGSize? = nil
    ) -> ImportResult {
        guard let loc = document.wrappedValue.assetsFolder,
              let editedRoot = loc.resolvedURL() else {
            return ImportResult(assetPath: AssetPath(), error: "Select an assets folder first.")
        }
        
        // Ensure SourceImages folder exists
        let sourceImagesFolder = editedRoot.appendingPathComponent("SourceImages", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: sourceImagesFolder,
                withIntermediateDirectories: true
            )
        } catch {
            return ImportResult(assetPath: AssetPath(), error: "Failed to prepare SourceImages folder: \(error.localizedDescription)")
        }
        
        // Copy original to SourceImages
        let originalDest = uniqueURL(in: sourceImagesFolder, for: sourceURL.lastPathComponent)
        do {
            if originalDest.standardizedFileURL != sourceURL.standardizedFileURL {
                try FileManager.default.copyItem(at: sourceURL, to: originalDest)
            }
        } catch {
            return ImportResult(assetPath: AssetPath(), error: "Failed to copy original: \(error.localizedDescription)")
        }
        
        // Determine edited destination
        let editedDest = uniqueURL(in: editedRoot, for: suggestedEditedFilename(label: label, from: sourceURL))
        
        // Load and render the image
        guard let srcImage = NSImage(contentsOf: originalDest) else {
            return ImportResult(assetPath: AssetPath(), error: "Failed to load image from: \(originalDest.path)")
        }
        
        // Determine aspect ratio
        let computedAspect: CGSize
        if case .custom = label, let customAspect = customAspect {
            computedAspect = customAspect
        } else if case .custom = label {
            // Use source image aspect for custom labels without override
            computedAspect = srcImage.size
        } else {
            // Use label's preset aspect
            computedAspect = label.targetAspect(using: srcImage)
        }
        
        // Render with cover options
        let maxPixels = label.preferredMaxPixels
        let opts = CoverRenderOptions(
            targetAspect: computedAspect,
            targetMaxPixels: maxPixels,
            output: .jpeg(0.95),
            enforceCover: true
        )
        
        do {
            if let rendered = CoverRender.renderCover(nsImage: srcImage, options: opts) {
                let tmp = editedDest.deletingLastPathComponent()
                    .appendingPathComponent(".tmp-\(UUID().uuidString)")
                    .appendingPathExtension(editedDest.pathExtension)
                try rendered.writeJPEG(to: tmp, quality: 0.95)
                try SafeFileWriter.atomicReplaceFile(at: editedDest, from: tmp)
            } else {
                // Fallback: copy original as-is
                try FileManager.default.copyItem(at: originalDest, to: editedDest)
            }
            
            let assetPath = AssetPath(
                pathToOriginal: originalDest.path,
                pathToEdited: editedDest.path,
                customAspectRatio: customAspect
            )
            return ImportResult(assetPath: assetPath, error: nil)
            
        } catch {
            return ImportResult(assetPath: AssetPath(), error: "Failed to save edited image: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Render and Save
    
    /// Re-renders an existing image from original path with new aspect ratio and saves to edited path
    /// - Parameters:
    ///   - label: The image label
    ///   - assetPath: Current asset path with original
    ///   - document: The Folio document
    ///   - customAspect: Optional custom aspect ratio override
    /// - Returns: Updated AssetPath with error message if any
    static func renderAndSave(
        label: ImageLabel,
        assetPath: AssetPath,
        document: FolioDocument,
        customAspect: CGSize? = nil
    ) -> ImportResult {
        guard let loc = document.assetsFolder,
              let editedRoot = loc.resolvedURL() else {
            return ImportResult(assetPath: assetPath, error: "Assets folder not set")
        }
        
        let originalURL = URL(fileURLWithPath: assetPath.pathToOriginal)
        guard let srcImage = NSImage(contentsOf: originalURL) else {
            return ImportResult(assetPath: assetPath, error: "Failed to load original image")
        }
        
        // Determine aspect ratio
        let computedAspect: CGSize
        if case .custom = label, let customAspect = customAspect {
            computedAspect = customAspect
        } else if case .custom = label {
            computedAspect = srcImage.size
        } else {
            computedAspect = label.targetAspect(using: srcImage)
        }
        
        let editedURL = URL(fileURLWithPath: assetPath.pathToEdited)
        let maxPixels = label.preferredMaxPixels
        let opts = CoverRenderOptions(
            targetAspect: computedAspect,
            targetMaxPixels: maxPixels,
            output: .jpeg(0.95),
            enforceCover: true
        )
        
        do {
            if let rendered = CoverRender.renderCover(nsImage: srcImage, options: opts) {
                let tmp = editedURL.deletingLastPathComponent()
                    .appendingPathComponent(".tmp-\(UUID().uuidString)")
                    .appendingPathExtension(editedURL.pathExtension)
                try rendered.writeJPEG(to: tmp, quality: 0.95)
                try SafeFileWriter.atomicReplaceFile(at: editedURL, from: tmp)
                
                // Clean up sidecar if exists
                deleteSidecar(for: editedURL)
            }
            
            var updatedPath = assetPath
            updatedPath.customAspectRatio = customAspect
            return ImportResult(assetPath: updatedPath, error: nil)
            
        } catch {
            return ImportResult(assetPath: assetPath, error: "Failed to re-render: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Image
    
    /// Deletes the edited image file and its sidecar JSON
    /// - Parameter assetPath: The asset path containing the edited path
    /// - Returns: Error message if deletion failed, nil otherwise
    @discardableResult
    static func deleteImage(assetPath: AssetPath?) -> String? {
        guard let editedPath = assetPath?.pathToEdited, !editedPath.isEmpty else {
            return nil
        }
        
        let editedURL = URL(fileURLWithPath: editedPath)
        
        // Delete the edited image
        if FileManager.default.fileExists(atPath: editedURL.path) {
            do {
                try FileManager.default.removeItem(at: editedURL)
            } catch {
                return "Failed to delete edited image: \(error.localizedDescription)"
            }
        }
        
        // Delete the sidecar JSON if it exists
        deleteSidecar(for: editedURL)
        
        return nil
    }
    
    // MARK: - Revert to Original
    
    /// Reverts image to original: re-renders from pathToOriginal, saves to pathToEdited, deletes sidecar
    /// - Parameters:
    ///   - label: The image label
    ///   - assetPath: Current asset path
    ///   - document: The Folio document
    /// - Returns: Updated AssetPath with error message if any
    static func revertToOriginal(
        label: ImageLabel,
        assetPath: AssetPath,
        document: FolioDocument
    ) -> ImportResult {
        // Delete sidecar first
        let editedURL = URL(fileURLWithPath: assetPath.pathToEdited)
        deleteSidecar(for: editedURL)
        
        // Re-render from original with no custom aspect (use defaults)
        return renderAndSave(label: label, assetPath: assetPath, document: document, customAspect: nil)
    }
    
    // MARK: - Relink Edited
    
    /// Allows user to select a replacement file for the edited image
    /// - Parameters:
    ///   - assetPath: Current asset path
    ///   - document: The Folio document
    /// - Returns: Updated AssetPath with new edited path, or original with error
    static func relinkEdited(assetPath: AssetPath, document: FolioDocument) -> ImportResult {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        // Set directory hint
        if !assetPath.pathToEdited.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: assetPath.pathToEdited).deletingLastPathComponent()
        } else if !assetPath.pathToOriginal.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: assetPath.pathToOriginal).deletingLastPathComponent()
        } else if let loc = document.assetsFolder, let root = loc.resolvedURL() {
            panel.directoryURL = root
        }
        
        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return ImportResult(assetPath: assetPath, error: nil) // User cancelled
        }
        
        guard let loc = document.assetsFolder, let root = loc.resolvedURL() else {
            return ImportResult(assetPath: assetPath, error: "Assets folder not set")
        }
        
        // Determine destination
        let destURL: URL
        if selectedURL.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path) {
            destURL = selectedURL
        } else {
            destURL = uniqueURL(in: root, for: selectedURL.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: selectedURL, to: destURL)
            } catch {
                return ImportResult(assetPath: assetPath, error: "Copy to assets folder failed: \(error.localizedDescription)")
            }
        }
        
        var updated = assetPath
        updated.pathToEdited = destURL.path
        return ImportResult(assetPath: updated, error: nil)
    }
    
    // MARK: - Helper Functions
    
    private static func suggestedEditedFilename(label: ImageLabel, from source: URL) -> String {
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        return "\(label.filenameBase).\(ext)"
    }
    
    private static func uniqueURL(in folder: URL, for filename: String) -> URL {
        var candidate = folder.appendingPathComponent(filename)
        let ext = candidate.pathExtension
        let base = candidate.deletingPathExtension().lastPathComponent
        var index = 1
        
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = "\(base) copy" + (index == 1 ? "" : " \(index)") + (ext.isEmpty ? "" : ".\(ext)")
            candidate = folder.appendingPathComponent(newName)
            index += 1
        }
        return candidate
    }
    
    /// Deletes the .json sidecar file associated with an edited image
    private static func deleteSidecar(for editedURL: URL) {
        let sidecarURL = editedURL.deletingPathExtension().appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: sidecarURL.path) {
            try? FileManager.default.removeItem(at: sidecarURL)
        }
    }
}

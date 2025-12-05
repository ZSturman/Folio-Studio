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
        panel.allowedContentTypes = [.image, .gif]
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
    
    // MARK: - Import Image
    
    /// Imports an image for a given label: stores original in app data, copies to assets folder
    /// Uses the image's native aspect ratio for simplicity
    /// - Parameters:
    ///   - label: The image label (thumbnail, banner, custom, etc.)
    ///   - sourceURL: The source image file URL
    ///   - document: The Folio document binding
    ///   - customAspect: Optional custom aspect ratio (stored but not applied during import)
    /// - Returns: ImportResult with the created AssetPath and any error message
    static func importImage(
        label: ImageLabel,
        sourceURL: URL,
        document: Binding<FolioDocument>,
        customAspect: CGSize? = nil
    ) -> ImportResult {
        guard let loc = document.wrappedValue.assetsFolder,
              let assetsFolderURL = loc.resolvedURL() else {
            return ImportResult(assetPath: AssetPath(), error: "Select an assets folder first.")
        }
        
        // Store original in app data and get UUID
        let imageID: UUID
        do {
            imageID = try ImageAssetManager.shared.storeOriginalFromURL(sourceURL)
        } catch {
            return ImportResult(assetPath: AssetPath(), error: "Failed to store original: \(error.localizedDescription)")
        }
        
        // Determine edited destination in assets folder - keep original extension for GIFs etc.
        let ext = sourceURL.pathExtension.lowercased()
        let editedFilename = "\(label.filenameBase).\(ext.isEmpty ? "png" : ext)"
        let editedDest = uniqueURL(in: assetsFolderURL, for: editedFilename)
        
        do {
            // Simply copy the file to preserve format (especially for GIFs)
            try FileManager.default.copyItem(at: sourceURL, to: editedDest)
            
            // Calculate relative path from assets folder
            let relativePath = editedDest.relativePath(from: assetsFolderURL) ?? editedDest.lastPathComponent
            
            // Store the image's native aspect ratio
            var nativeAspect: CGSize? = customAspect
            if nativeAspect == nil, let srcImage = NSImage(contentsOf: sourceURL) {
                nativeAspect = srcImage.size
            }
            
            let assetPath = AssetPath(
                id: imageID,
                path: relativePath,
                customAspectRatio: nativeAspect
            )
            return ImportResult(assetPath: assetPath, error: nil)
            
        } catch {
            return ImportResult(assetPath: AssetPath(), error: "Failed to save image: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Render and Save
    
    /// Re-renders an existing image from app data with new aspect ratio and saves to edited path
    /// - Parameters:
    ///   - label: The image label
    ///   - assetPath: Current asset path with UUID
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
              let assetsFolderURL = loc.resolvedURL() else {
            return ImportResult(assetPath: assetPath, error: "Assets folder not set")
        }
        
        // Load original from app data
        guard let srcImage = ImageAssetManager.shared.loadOriginal(id: assetPath.id) else {
            return ImportResult(assetPath: assetPath, error: "Failed to load original image")
        }
        
        // Determine aspect ratio
        let computedAspect: CGSize
        if let customAspect = customAspect {
            // Use custom aspect if provided (for poster rotation, custom labels, etc.)
            computedAspect = customAspect
        } else if case .custom = label {
            computedAspect = srcImage.size
        } else {
            computedAspect = label.targetAspect(using: srcImage)
        }
        
        // Determine edited destination
        let editedURL = assetsFolderURL.appendingPathComponent(assetPath.path)
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
            }
            
            var updatedPath = assetPath
            updatedPath.customAspectRatio = customAspect
            return ImportResult(assetPath: updatedPath, error: nil)
            
        } catch {
            return ImportResult(assetPath: assetPath, error: "Failed to re-render: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Image
    
    /// Deletes the edited image file, original from app data, and transform data
    /// - Parameters:
    ///   - assetPath: The asset path containing the ID and path
    ///   - assetsFolderURL: The assets folder URL to resolve relative path
    /// - Returns: Error message if deletion failed, nil otherwise
    @discardableResult
    static func deleteImage(assetPath: AssetPath?, assetsFolderURL: URL?) -> String? {
        guard let assetPath = assetPath else { return nil }
        
        // Delete original from app data
        ImageAssetManager.shared.deleteOriginal(id: assetPath.id)
        
        // Delete transform data
        ImageAssetManager.shared.deleteTransform(for: assetPath.id)
        
        // Delete edited image from assets folder
        if !assetPath.path.isEmpty, let assetsFolderURL = assetsFolderURL {
            let editedURL = assetsFolderURL.appendingPathComponent(assetPath.path)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                do {
                    try FileManager.default.removeItem(at: editedURL)
                } catch {
                    return "Failed to delete edited image: \(error.localizedDescription)"
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Revert to Original
    
    /// Reverts image to original: re-renders from app data, deletes transform data
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
        // Delete transform data
        ImageAssetManager.shared.deleteTransform(for: assetPath.id)
        
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
        panel.allowedContentTypes = [.image, .gif]
        
        // Set directory hint to assets folder
        if let loc = document.assetsFolder, let assetsFolderURL = loc.resolvedURL() {
            if !assetPath.path.isEmpty {
                panel.directoryURL = assetsFolderURL.appendingPathComponent(assetPath.path).deletingLastPathComponent()
            } else {
                panel.directoryURL = assetsFolderURL
            }
        }
        
        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return ImportResult(assetPath: assetPath, error: nil) // User cancelled
        }
        
        guard let loc = document.assetsFolder, let assetsFolderURL = loc.resolvedURL() else {
            return ImportResult(assetPath: assetPath, error: "Assets folder not set")
        }
        
        // Determine destination
        let destURL: URL
        if selectedURL.standardizedFileURL.path.hasPrefix(assetsFolderURL.standardizedFileURL.path) {
            destURL = selectedURL
        } else {
            destURL = uniqueURL(in: assetsFolderURL, for: selectedURL.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: selectedURL, to: destURL)
            } catch {
                return ImportResult(assetPath: assetPath, error: "Copy to assets folder failed: \(error.localizedDescription)")
            }
        }
        
        // Calculate relative path
        let relativePath = destURL.relativePath(from: assetsFolderURL) ?? destURL.lastPathComponent
        
        var updated = assetPath
        updated.path = relativePath
        return ImportResult(assetPath: updated, error: nil)
    }
    
    // MARK: - Helper Functions
    
    private static func suggestedEditedFilename(label: ImageLabel, from source: URL) -> String {
        let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension.lowercased()
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
}

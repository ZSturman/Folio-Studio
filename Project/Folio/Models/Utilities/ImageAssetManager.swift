//
//  ImageAssetManager.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import Foundation
import AppKit

/// Manages original images and transform data in app support directory
/// Originals stored at: ~/Library/Application Support/Folio/OriginalImages/{UUID}.{ext}
/// Transforms stored at: ~/Library/Application Support/Folio/Transforms/{UUID}.json
final class ImageAssetManager {
    static let shared = ImageAssetManager()
    
    private let fileManager = FileManager.default
    
    // Base directory: ~/Library/Application Support/Folio/
    private var appSupportURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Folio", isDirectory: true)
    }
    
    // Original images directory
    private var originalsURL: URL {
        appSupportURL.appendingPathComponent("OriginalImages", isDirectory: true)
    }
    
    // Transform metadata directory
    private var transformsURL: URL {
        appSupportURL.appendingPathComponent("Transforms", isDirectory: true)
    }
    
    private init() {
        ensureDirectories()
    }
    
    // MARK: - Directory Management
    
    private func ensureDirectories() {
        try? fileManager.createDirectory(at: originalsURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: transformsURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Original Image Storage
    
    /// Store original image in app data and return UUID identifier
    func storeOriginal(_ image: NSImage, fileExtension: String) throws -> UUID {
        let id = UUID()
        let destURL = originalsURL.appendingPathComponent("\(id.uuidString).\(fileExtension)")
        
        // Save image to app data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw ImageAssetError.imageConversionFailed
        }
        
        let imageData: Data?
        switch fileExtension.lowercased() {
        case "png":
            imageData = bitmapRep.representation(using: .png, properties: [:])
        case "jpg", "jpeg":
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        default:
            imageData = bitmapRep.representation(using: .png, properties: [:])
        }
        
        guard let data = imageData else {
            throw ImageAssetError.imageConversionFailed
        }
        
        try data.write(to: destURL)
        return id
    }
    
    /// Store original image from source URL in app data and return UUID identifier
    func storeOriginalFromURL(_ sourceURL: URL) throws -> UUID {
        let id = UUID()
        let fileExtension = sourceURL.pathExtension
        let destURL = originalsURL.appendingPathComponent("\(id.uuidString).\(fileExtension)")
        
        try fileManager.copyItem(at: sourceURL, to: destURL)
        return id
    }
    
    /// Load original image by UUID
    func loadOriginal(id: UUID) -> NSImage? {
        // Try common extensions
        for ext in ["png", "jpg", "jpeg", "heic", "tiff"] {
            let url = originalsURL.appendingPathComponent("\(id.uuidString).\(ext)")
            if fileManager.fileExists(atPath: url.path),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
    
    /// Get URL for original image by UUID (for file operations)
    func originalURL(id: UUID, extension ext: String) -> URL {
        originalsURL.appendingPathComponent("\(id.uuidString).\(ext)")
    }
    
    /// Delete original image by UUID
    func deleteOriginal(id: UUID) {
        // Try all common extensions
        for ext in ["png", "jpg", "jpeg", "heic", "tiff"] {
            let url = originalsURL.appendingPathComponent("\(id.uuidString).\(ext)")
            try? fileManager.removeItem(at: url)
        }
    }
    
    // MARK: - Transform Storage
    
    /// Save transform data for an image
    func saveTransform(_ transform: ImageTransformData, for id: UUID) throws {
        let url = transformsURL.appendingPathComponent("\(id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(transform)
        try data.write(to: url)
    }
    
    /// Load transform data for an image
    func loadTransform(for id: UUID) -> ImageTransformData? {
        let url = transformsURL.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ImageTransformData.self, from: data)
    }
    
    /// Delete transform data for an image
    func deleteTransform(for id: UUID) {
        let url = transformsURL.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - Cleanup
    
    /// Remove orphaned images and transforms not referenced in any document
    /// Call this with a set of all currently used UUIDs from open documents
    func cleanupOrphans(excluding activeIDs: Set<UUID>) async {
        await Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            let fm = FileManager.default
            let originalsURL = await self.originalsURL
            let transformsURL = await self.transformsURL
            
            // Cleanup original images
            if let originalFiles = try? fm.contentsOfDirectory(at: originalsURL, includingPropertiesForKeys: nil) {
                for fileURL in originalFiles {
                    let filename = fileURL.deletingPathExtension().lastPathComponent
                    if let uuid = UUID(uuidString: filename), !activeIDs.contains(uuid) {
                        try? fm.removeItem(at: fileURL)
                    }
                }
            }
            
            // Cleanup transform files
            if let transformFiles = try? fm.contentsOfDirectory(at: transformsURL, includingPropertiesForKeys: nil) {
                for fileURL in transformFiles {
                    let filename = fileURL.deletingPathExtension().lastPathComponent
                    if let uuid = UUID(uuidString: filename), !activeIDs.contains(uuid) {
                        try? fm.removeItem(at: fileURL)
                    }
                }
            }
        }.value
    }
}

// MARK: - Data Structures

/// Transform metadata stored in app data
struct ImageTransformData: Codable {
    var scale: CGFloat
    var translationX: CGFloat
    var translationY: CGFloat
    var rotationDegrees: CGFloat
    var aspectOverride: CGSize?
    
    init(scale: CGFloat = 1.0, translationX: CGFloat = 0, translationY: CGFloat = 0, rotationDegrees: CGFloat = 0, aspectOverride: CGSize? = nil) {
        self.scale = scale
        self.translationX = translationX
        self.translationY = translationY
        self.rotationDegrees = rotationDegrees
        self.aspectOverride = aspectOverride
    }
    
    /// Convert to ImageTransform for editor
    func toImageTransform() -> ImageTransform {
        ImageTransform(
            scale: scale,
            translation: CGSize(width: translationX, height: translationY),
            rotation: rotationDegrees
        )
    }
    
    /// Create from ImageTransform
    static func from(_ transform: ImageTransform, aspectOverride: CGSize? = nil) -> ImageTransformData {
        ImageTransformData(
            scale: transform.scale,
            translationX: transform.translation.width,
            translationY: transform.translation.height,
            rotationDegrees: transform.rotation,
            aspectOverride: aspectOverride
        )
    }
}

// MARK: - Errors

enum ImageAssetError: LocalizedError {
    case imageConversionFailed
    case originalNotFound
    case invalidUUID
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image for storage"
        case .originalNotFound:
            return "Original image not found in app data"
        case .invalidUUID:
            return "Invalid image identifier"
        }
    }
}

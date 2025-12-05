//
//  MediaDetailView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct MediaDetailView: View {
    @Binding var document: FolioDocument
    @State private var errorMessage: String?
    @Binding var selectedImageLabel: ImageLabel
    @ObservedObject var imageEditorViewModel: ImageEditorViewModel
    
    // Debounce for auto-save
    @State private var saveCancellable: AnyCancellable?
    
    // Drag and drop state
    @State private var dropIsTargeted = false

    private var jsonImage: AssetPath? {
        document.images[selectedImageLabel]
    }

    private var isCustomSelectedLabel: Bool {
        if case .custom = selectedImageLabel {
            return true
        }
        return false
    }
    
    private var isPresetLabel: Bool {
        !isCustomSelectedLabel
    }

    private func setJsonImage(_ newValue: AssetPath?) {
        document.images[selectedImageLabel] = newValue
    }

    private func removeImage() {
        guard let assetPath = jsonImage,
              let assetsFolderURL = document.assetsFolder?.resolvedURL() else {
            setJsonImage(nil)
            return
        }
        
        // Use ImageImportService to handle deletion
        ImageImportService.deleteImage(assetPath: assetPath, assetsFolderURL: assetsFolderURL)
        
        setJsonImage(nil)
        
        if document.images[selectedImageLabel] == nil {
            if let firstKey = document.images.keys.sorted().first {
                selectedImageLabel = ImageLabel(storageKey: firstKey)
            } else {
                selectedImageLabel = .thumbnail
            }
        }
    }

    private var isCurrentAssetEmpty: Bool {
        guard let asset = jsonImage else { return true }
        
        // Check if we have an original in app data
        if ImageAssetManager.shared.loadOriginal(id: asset.id) != nil {
            return false
        }
        
        // Fallback: Check if edited file exists at assets folder path (for legacy/reopened documents)
        if !asset.path.isEmpty,
           let assetsFolderURL = document.assetsFolder?.resolvedURL() {
            let editedURL = assetsFolderURL.appendingPathComponent(asset.path)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                return false
            }
        }
        
        // Also check legacy pathToEdited
        if let legacyPath = asset.pathToEdited, !legacyPath.isEmpty,
           FileManager.default.fileExists(atPath: legacyPath) {
            return false
        }
        
        return true
    }
    
    private func clearImageButKeepKey() {
        guard let assetPath = jsonImage,
              let assetsFolderURL = document.assetsFolder?.resolvedURL() else {
            imageEditorViewModel.removeImage()
            return
        }
        
        // Delete the image using ImageImportService
        ImageImportService.deleteImage(assetPath: assetPath, assetsFolderURL: assetsFolderURL)
        
        // Create an empty AssetPath to keep the key
        setJsonImage(AssetPath())
        imageEditorViewModel.removeImage()
    }
    
    // MARK: - Image URL for display
    
    /// Get the URL for displaying the current image (needed for GIF animation support)
    private var currentImageURL: URL? {
        guard let assetPath = jsonImage else { return nil }
        
        // Try relative path from assets folder first (the copied/edited file)
        if !assetPath.path.isEmpty,
           let assetsFolderURL = document.assetsFolder?.resolvedURL() {
            let editedURL = assetsFolderURL.appendingPathComponent(assetPath.path)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                return editedURL
            }
        }
        
        // Try legacy pathToEdited
        if let legacyPath = assetPath.pathToEdited, !legacyPath.isEmpty,
           FileManager.default.fileExists(atPath: legacyPath) {
            return URL(fileURLWithPath: legacyPath)
        }
        
        // Try to get original from app data
        // Note: This won't animate GIFs properly but at least shows the image
        return ImageAssetManager.shared.originalURL(for: assetPath.id)
    }
    
    /// Display view that supports animated GIFs with zoom and scroll
    @ViewBuilder
    private var imageDisplayView: some View {
        if let url = currentImageURL {
            ZoomableImageView(url: url)
        } else if let image = imageEditorViewModel.displayImage {
            // Fallback to static image display
            ZoomableImageView(nsImage: image)
        } else {
            // No image available
            VStack {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Image not available")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    // MARK: - Load Image into Editor
    
    private func loadImageIntoEditor() {
        guard let assetPath = jsonImage else {
            imageEditorViewModel.removeImage()
            return
        }
        
        // Try to load original from app data using UUID
        var image: NSImage? = ImageAssetManager.shared.loadOriginal(id: assetPath.id)
        
        // Fallback: Try to load from edited file path (for legacy/reopened documents)
        if image == nil {
            // Try relative path from assets folder
            if !assetPath.path.isEmpty,
               let assetsFolderURL = document.assetsFolder?.resolvedURL() {
                let editedURL = assetsFolderURL.appendingPathComponent(assetPath.path)
                image = NSImage(contentsOf: editedURL)
            }
            
            // Try legacy pathToEdited
            if image == nil,
               let legacyPath = assetPath.pathToEdited, !legacyPath.isEmpty {
                image = NSImage(contentsOf: URL(fileURLWithPath: legacyPath))
            }
        }
        
        guard let loadedImage = image else {
            imageEditorViewModel.removeImage()
            return
        }
        
        // Use the image's native aspect ratio (stored in customAspectRatio or from image size)
        // This simplifies the approach - no preset aspect ratios, just use what the image is
        imageEditorViewModel.selectedAspectRatio = .free
        
        // Load the image
        imageEditorViewModel.loadImage(loadedImage)
    }
    
    // MARK: - Save Transform Changes (disabled - using simple copy approach)
    /*
    private func saveTransformChanges() {
        guard let assetPath = jsonImage,
              !(assetPath.pathToOriginal?.isEmpty ?? true),
              !(assetPath.pathToEdited?.isEmpty ?? true) else {
            return
        }
        
        // Load from ORIGINAL for rendering
        let originalURL = URL(fileURLWithPath: assetPath.pathToOriginal ?? "")
        guard let originalImage = NSImage(contentsOf: originalURL) else {
            errorMessage = "Failed to load original image"
            return
        }
        
        let editedURL = URL(fileURLWithPath: assetPath.pathToEdited ?? "")
        
        // Convert ImageTransform to UserTransform
        let userTransform = UserTransform(
            scale: imageEditorViewModel.currentTransform.scale,
            rotationDegrees: imageEditorViewModel.currentTransform.rotation,
            translation: imageEditorViewModel.currentTransform.translation
        )
        
        // Prepare render options
        let targetAspect: CGSize
        if case .custom = selectedImageLabel, let customAspect = assetPath.customAspectRatio {
            targetAspect = customAspect
        } else {
            targetAspect = selectedImageLabel.targetAspect(using: originalImage)
        }
        
        let options = CoverRenderOptions(
            targetAspect: targetAspect,
            targetMaxPixels: selectedImageLabel.preferredMaxPixels,
            output: OutputFormat.png,
            enforceCover: true
        )
        
        // Render the cover image from ORIGINAL
        guard let renderedImage = CoverRender.renderCover(
            nsImage: originalImage,
            options: options,
            userTransform: userTransform
        ) else {
            errorMessage = "Failed to render image"
            return
        }
        
        // Save to edited path
        guard let tiffData = renderedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            errorMessage = "Failed to convert image"
            return
        }
        
        do {
            try pngData.write(to: editedURL)
            
            // Save sidecar with transform data
            let sidecar = EditedSidecar(
                transform: userTransform,
                aspectOverride: targetAspect
            )
            EditedSidecarIO.save(sidecar, for: editedURL)
            
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save: \\(error.localizedDescription)"
        }
    }
    */
    
    private func setupAutoSave() {
        // Transform editing disabled - no auto-save needed
        // Images are now copied directly with their native aspect ratio
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Show import button if no image exists
            if isCurrentAssetEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(dropIsTargeted ? Color.accentColor : .secondary)
                    
                    Text(dropIsTargeted ? "Drop image here" : "No image set for \(selectedImageLabel.title)")
                        .font(.headline)
                        .foregroundStyle(dropIsTargeted ? Color.accentColor : .secondary)
                    
                    Text("Drag and drop an image or click to browse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Import Image") {
                        if let sourceURL = ImageImportService.selectSourceImage() {
                            importImageFromURL(sourceURL)
                        }
                    }
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(dropIsTargeted ? Color.accentColor : Color.clear, lineWidth: 3)
                        .padding(8)
                )
                .onDrop(of: [.fileURL, .image], isTargeted: $dropIsTargeted) { providers in
                    handleDrop(providers: providers)
                }
            } else {
                // Display the image - use AnimatedImageView for GIF support
                imageDisplayView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 400)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
            }
        }
        .onAppear {
            setupAutoSave()
            loadImageIntoEditor()
        }
        .onChange(of: selectedImageLabel) { _, _ in
            loadImageIntoEditor()
        }
        .onChange(of: jsonImage) { _, _ in
            loadImageIntoEditor()
        }
    }
    
    // MARK: - Drag and Drop
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let fileProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            errorMessage = "Drop a file from Finder to import."
            return false
        }
        
        _ = fileProvider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load dropped file."
                }
                return
            }
            
            // Verify it's an image
            if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
               !type.conforms(to: .image) {
                DispatchQueue.main.async {
                    self.errorMessage = "Please drop an image file."
                }
                return
            }
            
            DispatchQueue.main.async {
                self.importImageFromURL(url)
            }
        }
        return true
    }
    
    // MARK: - Import Image
    
    private func importImageFromURL(_ sourceURL: URL) {
        guard document.assetsFolder != nil else {
            _ = AssetFolderManager.shared.ensureAssetsFolder(for: $document)
            guard document.assetsFolder != nil else {
                errorMessage = "Please select an assets folder first"
                return
            }
            return
        }
        
        let result = ImageImportService.importImage(
            label: selectedImageLabel,
            sourceURL: sourceURL,
            document: $document,
            customAspect: nil
        )
        
        if let error = result.error {
            errorMessage = error
        } else {
            document.images[selectedImageLabel] = result.assetPath
            errorMessage = nil
        }
    }
    
    // MARK: - Revert to Original
    
    private func revertToOriginal() {
        guard let assetPath = jsonImage else { return }
        
        let result = ImageImportService.revertToOriginal(
            label: selectedImageLabel,
            assetPath: assetPath,
            document: document
        )
        
        if let error = result.error {
            errorMessage = error
        } else {
            document.images[selectedImageLabel] = result.assetPath
            errorMessage = nil
            // Reload the editor with reverted image
            loadImageIntoEditor()
        }
    }
}


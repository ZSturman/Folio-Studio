//
//  MediaDetailView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//

import SwiftUI
import Combine

struct MediaDetailView: View {
    @Binding var document: FolioDocument
    @State private var errorMessage: String?
    @Binding var selectedImageLabel: ImageLabel
    @ObservedObject var imageEditorViewModel: ImageEditorViewModel
    
    // Debounce for auto-save
    @State private var saveCancellable: AnyCancellable?

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
        return ImageAssetManager.shared.loadOriginal(id: asset.id) == nil
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
    
    // MARK: - Load Image into Editor
    
    private func loadImageIntoEditor() {
        guard let assetPath = jsonImage else {
            imageEditorViewModel.removeImage()
            return
        }
        
        // Load original from app data using UUID
        guard let image = ImageAssetManager.shared.loadOriginal(id: assetPath.id) else {
            imageEditorViewModel.removeImage()
            return
        }
        
        // Set aspect ratio based on label (use custom aspect if set)
        if case .custom = selectedImageLabel, let _ = assetPath.customAspectRatio {
            // Custom label with aspect override - need to map CGSize to AspectRatio
            // For now, use free and the viewmodel will handle the custom size
            imageEditorViewModel.selectedAspectRatio = .free
        } else {
            imageEditorViewModel.selectedAspectRatio = selectedImageLabel.toAspectRatio()
        }
        
        // Load the image
        imageEditorViewModel.loadImage(image)
        
        // Load existing transform from sidecar if it exists
        let editedURL = URL(fileURLWithPath: assetPath.pathToEdited ?? "")
        if let sidecar = EditedSidecarIO.load(for: editedURL) {
            // Convert UserTransform to ImageTransform
            imageEditorViewModel.currentTransform = ImageTransform(
                cropRect: .zero, // Will be calculated
                scale: sidecar.transform.scale,
                translation: sidecar.transform.translation,
                rotation: sidecar.transform.rotationDegrees
            )
        }
    }
    
    // MARK: - Save Transform Changes
    
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
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func setupAutoSave() {
        // Watch for transform changes and debounce save
        saveCancellable = imageEditorViewModel.$currentTransform
            .dropFirst() // Ignore initial value
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [self] _ in
                saveTransformChanges()
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Show import button if no image exists
            if isCurrentAssetEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No image set for \(selectedImageLabel.title)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button("Import Image") {
                        if let sourceURL = ImageImportService.selectSourceImage() {
                            importImageFromURL(sourceURL)
                        }
                    }
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Image canvas with ImageEditor's ImageCanvasView
                ImageCanvasView(viewModel: imageEditorViewModel)
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


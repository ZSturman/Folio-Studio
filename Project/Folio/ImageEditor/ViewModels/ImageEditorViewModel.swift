//
//  ImageEditorViewModel.swift
//  ImageEditor
//

import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
class ImageEditorViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var originalImage: NSImage?
    @Published private(set) var displayImage: NSImage?
    @Published var currentTransform: ImageTransform = .identity
    @Published var selectedAspectRatio: AspectRatio = .free
    @Published var exportFormat: ExportFormat = .png
    @Published var editingState: EditingState = EditingState()
    @Published var saveURL: URL?
    
    // MARK: - Private Properties
    
    private var undoStack: [ImageTransform] = []
    private var redoStack: [ImageTransform] = []
    private var saveCancellable: AnyCancellable?
    private var canvasSize: CGSize = .zero
    
    // MARK: - Initialization
    
    init() {
        setupAutoSave()
    }
    
    // MARK: - Image Management
    
    func loadImage(_ image: NSImage) {
        print("loadImage called with image size: \(image.size)")
        originalImage = image
        
        // Reset transformation to identity
        currentTransform = .identity
        
        // Calculate initial crop rect based on aspect ratio
        if selectedAspectRatio != .free {
            currentTransform.cropRect = ImageProcessor.calculateInitialCropRect(
                for: image.size,
                aspectRatio: selectedAspectRatio
            )
        }
        
        // Clear undo/redo stacks
        undoStack.removeAll()
        redoStack.removeAll()
        
        updateEditingState()
        print("About to update display image")
        updateDisplayImage()
        print("Display image updated: \(displayImage?.size ?? .zero)")
    }
    
    func removeImage() {
        originalImage = nil
        displayImage = nil
        currentTransform = .identity
        undoStack.removeAll()
        redoStack.removeAll()
        updateEditingState()
    }
    
    func revertToOriginal() {
        guard originalImage != nil else { return }
        
        // Save current state to undo before reverting
        pushToUndoStack()
        
        currentTransform = .identity
        if selectedAspectRatio != .free, let image = originalImage {
            currentTransform.cropRect = ImageProcessor.calculateInitialCropRect(
                for: image.size,
                aspectRatio: selectedAspectRatio
            )
        }
        
        redoStack.removeAll()
        updateEditingState()
        updateDisplayImage()
    }
    
    // MARK: - Transformations
    
    func updateScale(_ scale: CGFloat) {
        pushToUndoStack()
        currentTransform.scale = scale
        redoStack.removeAll()
        updateEditingState()
        updateDisplayImage()
    }
    
    func updateRotation(_ rotation: CGFloat) {
        pushToUndoStack()
        currentTransform.rotation = rotation
        redoStack.removeAll()
        updateEditingState()
        updateDisplayImage()
    }
    
    func updateTranslation(_ translation: CGSize) {
        pushToUndoStack()
        currentTransform.translation = translation
        redoStack.removeAll()
        updateEditingState()
        updateDisplayImage()
    }
    
    func translate(dx: CGFloat, dy: CGFloat) {
        pushToUndoStack()
        currentTransform.translation.width += dx
        // Flip dy: positive dy in screen space means moving down, which is negative in image space
        currentTransform.translation.height -= dy
        redoStack.removeAll()
        updateEditingState()
        updateDisplayImage()
    }
    
    func updateCropRect(_ rect: CGRect) {
        pushToUndoStack()
        currentTransform.cropRect = rect
        redoStack.removeAll()
        updateEditingState()
        updateDisplayImage()
    }
    
    func updateAspectRatio(_ aspectRatio: AspectRatio) {
        selectedAspectRatio = aspectRatio
        
        // Recalculate crop rect for new aspect ratio
        if aspectRatio != .free, let image = originalImage {
            pushToUndoStack()
            currentTransform.cropRect = ImageProcessor.calculateInitialCropRect(
                for: image.size,
                aspectRatio: aspectRatio
            )
            redoStack.removeAll()
            updateEditingState()
        }
        
        updateDisplayImage()
    }
    
    // MARK: - Undo/Redo
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        redoStack.append(currentTransform)
        currentTransform = undoStack.removeLast()
        
        updateEditingState()
        updateDisplayImage()
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        undoStack.append(currentTransform)
        currentTransform = redoStack.removeLast()
        
        updateEditingState()
        updateDisplayImage()
    }
    
    private func pushToUndoStack() {
        // Only push if the transform has actually changed
        if undoStack.last != currentTransform {
            undoStack.append(currentTransform)
            
            // Limit undo stack size
            if undoStack.count > 50 {
                undoStack.removeFirst()
            }
        }
    }
    
    // MARK: - Display Updates
    
    func updateCanvasSize(_ size: CGSize) {
        canvasSize = size
        updateDisplayImage()
    }
    
    private func updateDisplayImage() {
        guard let original = originalImage else {
            print("No original image to display")
            displayImage = nil
            return
        }
        
        print("Processing image with canvas size: \(canvasSize)")
        displayImage = ImageProcessor.process(
            image: original,
            transform: currentTransform,
            aspectRatio: selectedAspectRatio,
            canvasSize: canvasSize
        )
        print("Processed display image: \(displayImage?.size ?? .zero)")
    }
    
    private func updateEditingState() {
        editingState.isImageLoaded = originalImage != nil
        editingState.canUndo = !undoStack.isEmpty
        editingState.canRedo = !redoStack.isEmpty
    }
    
    // MARK: - Auto-Save
    
    private func setupAutoSave() {
        saveCancellable = $currentTransform
            .debounce(for: .seconds(2.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.autoSave()
            }
    }
    
    private func autoSave() {
        guard let saveURL = saveURL,
              let original = originalImage else {
            return
        }
        
        Task {
            editingState.isSaving = true
            
            if let data = ImageProcessor.exportImage(
                original: original,
                transform: currentTransform,
                format: exportFormat
            ) {
                do {
                    try data.write(to: saveURL, options: .atomic)
                } catch {
                    print("Auto-save failed: \(error.localizedDescription)")
                }
            }
            
            editingState.isSaving = false
        }
    }
    
    // MARK: - Export
    
    func selectSaveLocation() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [exportFormat.utType]
        savePanel.nameFieldStringValue = "EditedImage.\(exportFormat.fileExtension)"
        savePanel.canCreateDirectories = true
        
        savePanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = savePanel.url else {
                return
            }
            
            self.saveURL = url
            self.autoSave() // Save immediately after selecting location
        }
    }
    
    func exportManually() {
        guard let original = originalImage else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [exportFormat.utType]
        savePanel.nameFieldStringValue = "EditedImage.\(exportFormat.fileExtension)"
        savePanel.canCreateDirectories = true
        
        savePanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = savePanel.url else {
                return
            }
            
            if let data = ImageProcessor.exportImage(
                original: original,
                transform: self.currentTransform,
                format: self.exportFormat
            ) {
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    print("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

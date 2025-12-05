//
//  MediaInspectorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct MediaInspectorView: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    let selectedLabel: ImageLabel
    @Binding var document: FolioDocument
    let onImageImported: (NSImage) -> Void
    let onRevertToOriginal: () -> Void
    let onClearImage: () -> Void
    
    @State private var isImporting = false
    @State private var customRotation: String = "0"
    @State private var importError: String?
    @State private var showCopyOriginalInfo = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Import Section
                importSection
                
                Divider()
                
                // Image Properties Section
                imagePropertiesSection
                
                // NOTE: Image editing controls temporarily disabled for simplicity
                // Images are now imported with their native aspect ratio
                // Uncomment below to re-enable transform/scale/rotation editing
                
                /*
                Divider()
                
                // Aspect Ratio Section
                aspectRatioSection
                
                if viewModel.editingState.isImageLoaded {
                    Divider()
                    
                    // Transform Controls
                    transformSection
                    
                    Divider()
                    
                    // Scale Control
                    scaleSection
                    
                    Divider()
                    
                    // Rotation Control
                    rotationSection
                    
                    Divider()
                    
                    // History Controls
                    historySection
                }
                */
                
                Divider()
                
                // Action Buttons
                actionsSection
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.image, .gif],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result)
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image")
                .font(.headline)
            
            Button(action: {
                isImporting = true
            }) {
                Label("Import Image", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(viewModel.editingState.isSaving)
        }
    }
    
    private func handleImageImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Use ImageImportService to handle the import
            let importResult = ImageImportService.importImage(
                label: selectedLabel,
                sourceURL: url,
                document: Binding(
                    get: { document },
                    set: { document = $0 }
                ),
                customAspect: nil
            )
            
            if let error = importResult.error {
                importError = error
            } else {
                // Update document
                document.images[selectedLabel] = importResult.assetPath
                importError = nil
                
                // Load the imported image into the editor
                if let image = NSImage(contentsOf: url) {
                    onImageImported(image)
                }
            }
            
        case .failure(let error):
            importError = "Import error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Image Properties Section
    
    private var imagePropertiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Properties")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Label:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(selectedLabel.title)
                }
                .font(.subheadline)
                
                // Show actual image dimensions if available
                if let assetPath = document.images[selectedLabel],
                   let customAspect = assetPath.customAspectRatio {
                    HStack {
                        Text("Size:")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text("\(Int(customAspect.width)) × \(Int(customAspect.height))")
                    }
                    .font(.subheadline)
                }
                
                if let error = importError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.leading, 8)
        }
    }
    
    // MARK: - Aspect Ratio Section
    
    private var aspectRatioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Aspect Ratio")
                    .font(.headline)
                
                if isPresetLabel {
                    Text("(Fixed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if isPresetLabel {
                // Show read-only aspect ratio for presets
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("This preset uses a fixed aspect ratio: \(viewModel.selectedAspectRatio.displayRatio)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                    }
                    
                    // Poster orientation flip button
                    if isPosterLabel {
                        HStack(spacing: 8) {
                            Button(action: flipPosterOrientation) {
                                Label(
                                    isPosterLandscape ? "Switch to Portrait (2:3)" : "Switch to Landscape (3:2)",
                                    systemImage: "rotate.right"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .help(isPosterLandscape ? "Switch to portrait orientation (2:3)" : "Switch to landscape orientation (3:2)")
                        }
                        
                        Text(isPosterLandscape ? "Current: Landscape (3:2)" : "Current: Portrait (2:3)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Show aspect ratio picker for custom labels
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(AspectRatio.allCases) { ratio in
                        Button(action: {
                            updateCustomAspectRatio(ratio)
                        }) {
                            AspectRatioPreviewBox(
                                aspectRatio: ratio,
                                isSelected: viewModel.selectedAspectRatio == ratio
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var isPresetLabel: Bool {
        switch selectedLabel {
        case .thumbnail, .banner, .heroBanner, .poster, .icon:
            return true
        case .custom:
            return false
        }
    }
    
    private var isPosterLabel: Bool {
        if case .poster = selectedLabel { return true }
        return false
    }
    
    /// Returns true if the current poster is in landscape orientation (3:2)
    private var isPosterLandscape: Bool {
        guard let assetPath = document.images[selectedLabel],
              let custom = assetPath.customAspectRatio else {
            return false // Default is portrait (2:3)
        }
        return custom.width > custom.height
    }
    
    /// Toggle poster orientation between portrait (2:3) and landscape (3:2)
    private func flipPosterOrientation() {
        var currentPath = document.images[selectedLabel] ?? AssetPath()
        
        // Toggle between portrait and landscape
        if isPosterLandscape {
            // Switch to portrait (2:3) - clear custom to use default
            currentPath.customAspectRatio = nil
        } else {
            // Switch to landscape (3:2)
            currentPath.customAspectRatio = CGSize(width: 3, height: 2)
        }
        
        document.images[selectedLabel] = currentPath
        
        // Update view model aspect ratio
        if isPosterLandscape {
            viewModel.selectedAspectRatio = .photo // 3:2
        } else {
            viewModel.selectedAspectRatio = .poster // 2:3
        }
        
        // Re-render if image exists
        if !currentPath.path.isEmpty || ImageAssetManager.shared.loadOriginal(id: currentPath.id) != nil {
            let result = ImageImportService.renderAndSave(
                label: selectedLabel,
                assetPath: currentPath,
                document: document,
                customAspect: currentPath.customAspectRatio
            )
            if result.error == nil {
                document.images[selectedLabel] = result.assetPath
            } else {
                importError = result.error
            }
        }
    }
    
    private func updateCustomAspectRatio(_ ratio: AspectRatio) {
        guard case .custom = selectedLabel else { return }
        
        viewModel.updateAspectRatio(ratio)
        
        // Update customAspectRatio in document if not .free
        if let ratioValue = ratio.ratio, ratio != .free {
            var currentPath = document.images[selectedLabel] ?? AssetPath()
            currentPath.customAspectRatio = CGSize(width: ratioValue, height: 1.0)
            document.images[selectedLabel] = currentPath
            
            // Re-render if image exists
            if !(currentPath.pathToOriginal?.isEmpty ?? true) {
                let result = ImageImportService.renderAndSave(
                    label: selectedLabel,
                    assetPath: currentPath,
                    document: document,
                    customAspect: currentPath.customAspectRatio
                )
                if result.error == nil {
                    document.images[selectedLabel] = result.assetPath
                }
            }
        } else if ratio == .free {
            var currentPath = document.images[selectedLabel] ?? AssetPath()
            currentPath.customAspectRatio = nil
            document.images[selectedLabel] = currentPath
        }
    }
    
    // MARK: - Transform Section
    
    private var transformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position")
                .font(.headline)
            
            VStack(spacing: 8) {
                // Up/Down buttons
                HStack(spacing: 12) {
                    Spacer()
                    Button(action: {
                        viewModel.translate(dx: 0, dy: -10)
                    }) {
                        Image(systemName: "arrow.up")
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                
                // Left/Right buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.translate(dx: -10, dy: 0)
                    }) {
                        Image(systemName: "arrow.left")
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.translate(dx: 10, dy: 0)
                    }) {
                        Image(systemName: "arrow.right")
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack(spacing: 12) {
                    Spacer()
                    Button(action: {
                        viewModel.translate(dx: 0, dy: 10)
                    }) {
                        Image(systemName: "arrow.down")
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
            .padding(.leading, 8)
        }
    }
    
    // MARK: - Scale Section
    
    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scale")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.2f", viewModel.currentTransform.scale))x")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Text("0.1x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { viewModel.currentTransform.scale },
                        set: { viewModel.updateScale($0) }
                    ),
                    in: 0.1...3.0,
                    step: 0.01
                )
                
                Text("3.0x")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Button("Reset") {
                    viewModel.updateScale(1.0)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
            .padding(.leading, 8)
        }
    }
    
    // MARK: - Rotation Section
    
    private var rotationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rotation")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.0f", viewModel.currentTransform.rotation))°")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Rotation buttons and text field
            HStack(spacing: 8) {
                Button(action: {
                    let current = viewModel.currentTransform.rotation
                    // Counterclockwise = positive rotation in standard coordinates
                    viewModel.updateRotation(current + 90)
                    customRotation = String(format: "%.0f", current + 90)
                }) {
                    Label("Rotate Counterclockwise", systemImage: "rotate.left")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Rotate 90° counterclockwise")
                
                Button(action: {
                    let current = viewModel.currentTransform.rotation
                    // Clockwise = negative rotation in standard coordinates  
                    viewModel.updateRotation(current - 90)
                    customRotation = String(format: "%.0f", current - 90)
                }) {
                    Label("Rotate Clockwise", systemImage: "rotate.right")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Rotate 90° clockwise")
            }
            
            // Custom degree input
            HStack(spacing: 8) {
                Text("Degrees:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField("0", text: $customRotation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit {
                        if let degrees = Double(customRotation) {
                            viewModel.updateRotation(degrees)
                        }
                    }
                    .onChange(of: viewModel.currentTransform.rotation) { _, newValue in
                        customRotation = String(format: "%.0f", newValue)
                    }
                
                Button("Apply") {
                    if let degrees = Double(customRotation) {
                        viewModel.updateRotation(degrees)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack(spacing: 8) {
                Button("Reset") {
                    viewModel.updateRotation(0)
                    customRotation = "0"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
            .padding(.leading, 8)
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)
            
            HStack(spacing: 8) {
                Button(action: {
                    viewModel.undo()
                }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.editingState.canUndo)
                .controlSize(.regular)
                
                Button(action: {
                    viewModel.redo()
                }) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.editingState.canRedo)
                .controlSize(.regular)
            }
            
            Button(action: {
                onRevertToOriginal()
            }) {
                Label("Revert to Original", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.editingState.isImageLoaded)
            .controlSize(.regular)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            Button(action: {
                onClearImage()
            }) {
                Label("Clear Image", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.editingState.isImageLoaded)
            .controlSize(.regular)
        
            
            // Only show Delete Image Key for custom labels
            if isCustomLabel {
                Button(role: .destructive, action: {
                    deleteImageKey()
                }) {
                    Label("Delete Image Key", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(document.images[selectedLabel] == nil)
                .controlSize(.regular)
            }
        }
    }
    
    private var canShowCopyOriginal: Bool {
        guard let current = document.images[selectedLabel],
              let originalPath = current.pathToOriginal, !originalPath.isEmpty,
              let editedPath = current.pathToEdited, !editedPath.isEmpty,
              let loc = document.assetsFolder,
              let root = loc.resolvedURL()
        else {
            return false
        }

        let originalURL = URL(fileURLWithPath: originalPath)
        let sourceImagesFolder = root.appendingPathComponent("SourceImages", isDirectory: true)
        let destURL = uniqueURL(in: sourceImagesFolder, for: originalURL.lastPathComponent)

        return destURL.standardizedFileURL.path != originalURL.standardizedFileURL.path
    }
    
    private var isCustomLabel: Bool {
        if case .custom = selectedLabel {
            return true
        }
        return false
    }
    
    private func deleteImageKey() {
        if let editedPath = document.images[selectedLabel]?.pathToEdited, !editedPath.isEmpty {
            let editedURL = URL(fileURLWithPath: editedPath)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                try? FileManager.default.removeItem(at: editedURL)
            }
        }
        document.images[selectedLabel] = nil
    }
    
    private func uniqueURL(in folder: URL, for filename: String) -> URL {
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

//// MARK: - Aspect Ratio Preview Box
//
//struct AspectRatioPreviewBox: View {
//    let aspectRatio: AspectRatio
//    let isSelected: Bool
//    
//    var body: some View {
//        VStack(spacing: 6) {
//            ZStack {
//                // Container box
//                RoundedRectangle(cornerRadius: 8)
//                    .fill(Color(NSColor.controlBackgroundColor))
//                    .frame(width: 70, height: 70)
//                
//                // Aspect ratio preview
//                if let ratio = aspectRatio.ratio {
//                    RoundedRectangle(cornerRadius: 4)
//                        .strokeBorder(
//                            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
//                        )
//                        .foregroundColor(isSelected ? .accentColor : .secondary)
//                        .aspectRatio(ratio, contentMode: .fit)
//                        .padding(10)
//                } else {
//                    // Free form - show full box
//                    RoundedRectangle(cornerRadius: 4)
//                        .strokeBorder(
//                            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
//                        )
//                        .foregroundColor(isSelected ? .accentColor : .secondary)
//                        .padding(10)
//                }
//            }
//            .overlay(
//                RoundedRectangle(cornerRadius: 8)
//                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
//            )
//            
//            VStack(spacing: 1) {
//                Text(aspectRatio.name)
//                    .font(.caption2)
//                    .fontWeight(isSelected ? .semibold : .regular)
//                    .lineLimit(1)
//                
//                Text(aspectRatio.displayRatio)
//                    .font(.system(size: 9))
//                    .foregroundColor(.secondary)
//            }
//        }
//        .frame(maxWidth: .infinity)
//    }
//}

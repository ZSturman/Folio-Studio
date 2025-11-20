//
//  EditingControlsView.swift
//  ImageEditor
//

import SwiftUI
import UniformTypeIdentifiers

struct EditingControlsView: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    @State private var isImporting = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Import/Remove Section
                imageManagementSection
                
                Divider()
                
                if viewModel.editingState.isImageLoaded {
                    // Transform Controls
                    transformSection
                    
                    Divider()
                    
                    // Scale Control
                    scaleSection
                    
                    Divider()
                    
                    // Rotation Control
                    rotationSection
                    
                    Divider()
                    
                    // Export Settings
                    exportSection
                    
                    Divider()
                    
                    // Undo/Redo/Revert
                    historySection
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageImport(result)
        }
    }
    
    // MARK: - Sections
    
    private var imageManagementSection: some View {
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
            
            if viewModel.editingState.isImageLoaded {
                Button(action: {
                    viewModel.removeImage()
                }) {
                    Label("Remove Image", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .tint(.red)
            }
        }
    }
    
    private var transformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position")
                .font(.headline)
            
            // Translation arrows
            VStack(spacing: 8) {
                // Up arrow
                Button(action: {
                    viewModel.translate(dx: 0, dy: 10)
                }) {
                    Image(systemName: "arrow.up")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                
                HStack(spacing: 8) {
                    // Left arrow
                    Button(action: {
                        viewModel.translate(dx: -10, dy: 0)
                    }) {
                        Image(systemName: "arrow.left")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    
                    // Center button (reset position)
                    Button(action: {
                        viewModel.updateTranslation(.zero)
                    }) {
                        Image(systemName: "scope")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    
                    // Right arrow
                    Button(action: {
                        viewModel.translate(dx: 10, dy: 0)
                    }) {
                        Image(systemName: "arrow.right")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Down arrow
                Button(action: {
                    viewModel.translate(dx: 0, dy: -10)
                }) {
                    Image(systemName: "arrow.down")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scale")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(viewModel.currentTransform.scale * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { viewModel.currentTransform.scale },
                        set: { viewModel.updateScale($0) }
                    ),
                    in: 0.1...3.0,
                    step: 0.01
                )
                
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(.secondary)
            }
            
            Button("Reset Scale") {
                viewModel.updateScale(1.0)
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var rotationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rotation")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(viewModel.currentTransform.rotation * 180 / .pi))°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "rotate.left")
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { viewModel.currentTransform.rotation },
                        set: { viewModel.updateRotation($0) }
                    ),
                    in: -.pi...(.pi),
                    step: 0.01
                )
                
                Image(systemName: "rotate.right")
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Button("90° CCW") {
                    viewModel.updateRotation(viewModel.currentTransform.rotation - .pi / 2)
                }
                .controlSize(.small)
                
                Button("Reset") {
                    viewModel.updateRotation(0)
                }
                .controlSize(.small)
                
                Button("90° CW") {
                    viewModel.updateRotation(viewModel.currentTransform.rotation + .pi / 2)
                }
                .controlSize(.small)
            }
        }
    }
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export")
                .font(.headline)
            
            // Format picker
            Picker("Format", selection: $viewModel.exportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            
            // Save location
            VStack(alignment: .leading, spacing: 8) {
                if let saveURL = viewModel.saveURL {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                        Text(saveURL.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if viewModel.editingState.isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                
                Button(action: {
                    viewModel.selectSaveLocation()
                }) {
                    Label(
                        viewModel.saveURL == nil ? "Select Save Location" : "Change Location",
                        systemImage: "folder.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
            }
            
            Button(action: {
                viewModel.exportManually()
            }) {
                Label("Export Now", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .tint(.accentColor)
            
            Text("Changes auto-save after 2 seconds")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
    
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
                viewModel.revertToOriginal()
            }) {
                Label("Revert to Original", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .tint(.orange)
        }
    }
    
    // MARK: - Helpers
    
    private func handleImageImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                print("No URL selected")
                return
            }
            
            print("=== IMAGE IMPORT DEBUG ===")
            print("URL: \(url)")
            print("URL path: \(url.path)")
            print("URL absoluteString: \(url.absoluteString)")
            print("URL isFileURL: \(url.isFileURL)")
            
            // Check if file exists and is readable
            let fileManager = FileManager.default
            let fileExists = fileManager.fileExists(atPath: url.path)
            print("File exists: \(fileExists)")
            
            if !fileExists {
                print("ERROR: File does not exist at path")
                // Try with standardized path
                let standardizedPath = (url.path as NSString).standardizingPath
                print("Trying standardized path: \(standardizedPath)")
                if fileManager.fileExists(atPath: standardizedPath) {
                    print("File exists at standardized path")
                }
                return
            }
            
            let isReadable = fileManager.isReadableFile(atPath: url.path)
            print("File is readable: \(isReadable)")
            
            if !isReadable {
                print("ERROR: File is not readable")
                
                // Check permissions
                if let attributes = try? fileManager.attributesOfItem(atPath: url.path) {
                    print("File attributes: \(attributes)")
                    if let permissions = attributes[.posixPermissions] as? NSNumber {
                        print("File permissions: \(String(format: "%o", permissions.intValue))")
                    }
                } else {
                    print("Could not get file attributes")
                }
                
                // Check if we can at least access the URL with security scoping
                let accessing = url.startAccessingSecurityScopedResource()
                print("Started accessing security scoped resource: \(accessing)")
                
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                        print("Stopped accessing security scoped resource")
                    }
                }
                
                // Try again after starting security scope access
                let isReadableAfterScope = fileManager.isReadableFile(atPath: url.path)
                print("File is readable after security scope: \(isReadableAfterScope)")
                
                if !isReadableAfterScope {
                    return
                }
            }
            
            // Check file size
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int {
                print("File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
            }
            
            // Start accessing security scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            print("Security scoped resource access: \(accessing)")
            
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Try multiple methods to load the image
            var image: NSImage?
            
            // Method 1: Direct NSImage init
            print("Trying Method 1: NSImage(contentsOf:)")
            image = NSImage(contentsOf: url)
            if image != nil {
                print("✓ Method 1 succeeded - image size: \(image!.size)")
            } else {
                print("✗ Method 1 failed")
            }
            
            // Method 2: Load via Data if method 1 fails
            if image == nil {
                print("Trying Method 2: NSImage(data:)")
                do {
                    let data = try Data(contentsOf: url)
                    print("Data loaded: \(data.count) bytes")
                    image = NSImage(data: data)
                    if image != nil {
                        print("✓ Method 2 succeeded - image size: \(image!.size)")
                    } else {
                        print("✗ Method 2 failed - NSImage(data:) returned nil")
                    }
                } catch {
                    print("✗ Method 2 failed - could not load data: \(error.localizedDescription)")
                }
            }
            
            // Method 3: Load via NSBitmapImageRep if method 2 fails
            if image == nil {
                print("Trying Method 3: NSBitmapImageRep")
                do {
                    let data = try Data(contentsOf: url)
                    if let bitmap = NSBitmapImageRep(data: data) {
                        print("Bitmap created: \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
                        let size = NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
                        image = NSImage(size: size)
                        image?.addRepresentation(bitmap)
                        print("✓ Method 3 succeeded - image size: \(image!.size)")
                    } else {
                        print("✗ Method 3 failed - could not create NSBitmapImageRep from data")
                    }
                } catch {
                    print("✗ Method 3 failed - could not load data: \(error.localizedDescription)")
                }
            }
            
            // Method 4: Try using CGImageSource
            if image == nil {
                print("Trying Method 4: CGImageSource")
                if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
                    let imageCount = CGImageSourceGetCount(imageSource)
                    print("Image source created with \(imageCount) image(s)")
                    
                    if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                        print("CGImage created: \(cgImage.width)x\(cgImage.height)")
                        let size = NSSize(width: cgImage.width, height: cgImage.height)
                        image = NSImage(cgImage: cgImage, size: size)
                        print("✓ Method 4 succeeded - image size: \(image!.size)")
                    } else {
                        print("✗ Method 4 failed - could not create CGImage at index 0")
                    }
                } else {
                    print("✗ Method 4 failed - could not create CGImageSource")
                }
            }
            
            if let loadedImage = image {
                print("=== IMAGE LOADED SUCCESSFULLY ===")
                print("Final image size: \(loadedImage.size)")
                print("Image representations: \(loadedImage.representations.count)")
                for (index, rep) in loadedImage.representations.enumerated() {
                    print("  Rep \(index): \(type(of: rep)) - \(rep.pixelsWide)x\(rep.pixelsHigh)")
                }
                viewModel.loadImage(loadedImage)
            } else {
                print("=== FAILED TO LOAD IMAGE ===")
                print("All methods failed to create NSImage from URL")
            }
            
        case .failure(let error):
            print("Image import failed: \(error.localizedDescription)")
        }
    }
}

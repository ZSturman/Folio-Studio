//
//  ImageSlotView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine

extension Notification.Name {
    static let assetFolderPermissionGranted = Notification.Name("AssetFolderPermissionGranted")
}

struct ImageSlotView: View {
    let label: ImageLabel
    @Binding var jsonImage: AssetPath?
    @Binding var document: FolioDocument
    
    @State private var dropIsTargeted = false
    @State private var errorMessage: String?
    @State private var permissionRefreshToken = UUID()
    @State private var isHovered = false
    @State private var requiresPermission = false
    @State private var hasValidatedAssetsFolderThisSession = false
    
    @Binding var labelPrefix: String
    
    // MARK: - Derived aspect ratio for the slot
    
    /// Default aspect from the label when we do not have an image yet.
    private var defaultAspect: CGFloat {
        // Use the label's targetAspect(using:) but pass nil so it gives the canonical preset.
        let sz = label.targetAspect(using: nil)
        guard sz.width > 0, sz.height > 0 else { return 1.0 }
        return sz.width / sz.height
    }
    
    /// Current aspect ratio the slot should use.
    /// Now uses the image's native aspect ratio for all labels (fill the frame approach)
    private var slotAspect: CGFloat {
        // First check customAspectRatio stored in the asset path
        if let assetPath = jsonImage, let customAspect = assetPath.customAspectRatio,
           customAspect.width > 0, customAspect.height > 0 {
            return customAspect.width / customAspect.height
        }
        
        // Then check the actual image dimensions
        if let url = editedURLIfExists,
           let img = NSImage(contentsOf: url),
           img.size.width > 0,
           img.size.height > 0 {
            // Use image's native aspect for all labels
            return img.size.width / img.size.height
        }
        return defaultAspect
    }
    
    private var borderColor: Color {
        if requiresPermission {
            return .yellow
        }
        if dropIsTargeted {
            return .accentColor
        }
        return .secondary
    }
    
    // MARK: - Paths / URLs
    
    private var editedURLIfExists: URL? {
        _ = permissionRefreshToken
        guard let assetPath = jsonImage, !assetPath.path.isEmpty else { return nil }
        
        // Resolve using assetsFolder + relative path
        guard let assetsFolderURL = document.assetsFolder?.resolvedURL() else {
            // Fallback to legacy pathToEdited for backwards compatibility
            if let legacyPath = assetPath.pathToEdited, !legacyPath.isEmpty,
               FileManager.default.fileExists(atPath: legacyPath) {
                return URL(fileURLWithPath: legacyPath)
            }
            return nil
        }
        
        let fullURL = assetsFolderURL.appendingPathComponent(assetPath.path)
        guard FileManager.default.fileExists(atPath: fullURL.path) else { return nil }
        return fullURL
    }
    
    private var editedPathValue: String? {
        guard let assetPath = jsonImage else { return nil }
        
        // Return relative path if available, otherwise legacy path
        if !assetPath.path.isEmpty {
            return assetPath.path
        }
        if let legacyPath = assetPath.pathToEdited, !legacyPath.isEmpty {
            return legacyPath
        }
        return nil
    }
    
    private var originalURLIfExists: URL? {
        // Original images are now stored in app data by UUID
        // This is only used for legacy support
        guard let assetPath = jsonImage,
              let legacyPath = assetPath.pathToOriginal,
              !legacyPath.isEmpty,
              FileManager.default.fileExists(atPath: legacyPath) else {
            return nil
        }
        return URL(fileURLWithPath: legacyPath)
    }
    
    // MARK: - Body
    
    
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            
            ZStack {
                // Background slot outline that will be constrained by .aspectRatio below
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(borderColor)
                
                Group {
                    if let url = editedURLIfExists {
                        let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path, from: document.documentWrapper)
                        ?? (PermissionHelper.isReadable(url) ? url : nil)
                        
                        if let u = readableURL,
                           let img = NSImage(contentsOf: u) {
                            VStack(spacing: 6) {
                                LabeledImagePreview(nsImage: img)
                                // Image editing now happens in the Media tab inspector
                            }
                        } else {
                            VStack {
                                
                                PermissionRequiredRow(title: label.title, url: url ) { grantedURL in
                                    let folderPath = grantedURL.deletingLastPathComponent().path
                                    NotificationCenter.default.post(
                                        name: .assetFolderPermissionGranted,
                                        object: nil,
                                        userInfo: ["folderPath": folderPath]
                                    )
                                    permissionRefreshToken = UUID()
                                    
                                }
                                Button(role: .destructive) { removeImage() } label: {
                                    Text("Remove")
                                }
                                
                            }
                        }
                        
                        
                    } else if let editedValue = editedPathValue, !editedValue.isEmpty {
                        VStack(spacing: 10) {
                            Text("Image not found")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(editedValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            HStack(spacing: 8) {
                                Button("Relink…") { relinkEdited() }
                                Button("Use Original image") { useOriginalAsEdited() }
                                    .disabled(originalURLIfExists == nil || document.assetsFolder == nil)
                                Button("Clear") { removeImage() }
                            }
                        }
                        .padding()
                    } else {
                        VStack(spacing: 6) {
                            Button("\(labelPrefix) \(label.title)") {
                                if ensureAssetsFolder() {
                                    importViaDialog()
                                }
                            }
                        }
                    }
                }
            }
            
            // Key change: height is now derived from aspect ratio.
            // Width is flexible given by the parent.
            .aspectRatio(slotAspect, contentMode: .fit)
            .frame(minWidth: 50, idealWidth: 200, maxWidth: 900)
            .onDrop(of: [.fileURL], isTargeted: $dropIsTargeted) { providers in
                handleDrop(providers: providers)
            }
            
            
            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            
            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption)
            }

        }
        .onReceive(NotificationCenter.default.publisher(for: .assetFolderPermissionGranted)) { notification in
            guard
                let folderPath = notification.userInfo?["folderPath"] as? String,
                let editedPath = jsonImage?.pathToEdited,
                !editedPath.isEmpty
            else { return }
            
            let thisFolderPath = URL(fileURLWithPath: editedPath)
                .deletingLastPathComponent()
                .path
            if thisFolderPath == folderPath {
                permissionRefreshToken = UUID()
            }
        }
        .onAppear {
            updatePermissionState()
        }
        .onChange(of: permissionRefreshToken) {
            updatePermissionState()
        }
        .onChange(of: jsonImage?.pathToEdited ?? "") {
            updatePermissionState()
        }
    }

    
    // MARK: - Assets folder
    
    @discardableResult
    private func ensureAssetsFolder() -> Bool {
        // If we have already validated the folder in this run and it is set, reuse it.
        if hasValidatedAssetsFolderThisSession, document.assetsFolder != nil {
            return true
        }
        
        if let _ = AssetFolderManager.shared.ensureAssetsFolder(for: $document) {
            hasValidatedAssetsFolderThisSession = true
            errorMessage = nil
            return true
        } else {
            return false
        }
    }
    
    private func chooseAssetFolderDialog() {
        _ = ensureAssetsFolder()
    }
    
    // MARK: - Import
    
    private func importViaDialog() {
        guard ensureAssetsFolder() else { return }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .gif]
        
        if panel.runModal() == .OK, let url = panel.url {
            handlePickedSource(url)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard ensureAssetsFolder() else { return false }
        
        if let fileProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) {
            _ = fileProvider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { handlePickedSource(url) }
            }
            return true
        }
        
        DispatchQueue.main.async {
            self.errorMessage = "Drop a file from Finder or use Import…."
        }
        return false
    }
    
    private func handlePickedSource(_ sourceURL: URL) {
        guard ensureAssetsFolder() else {
            errorMessage = "Select an assets folder first."
            return
        }
        
        // Use ImageImportService to handle the import
        let result = ImageImportService.importImage(
            label: label,
            sourceURL: sourceURL,
            document: $document,
            customAspect: nil
        )
        
        if let error = result.error {
            errorMessage = error
        } else {
            jsonImage = result.assetPath
            errorMessage = nil
        }
    }
    
    // MARK: - Relink / reuse
    
    private func relinkEdited() {
        guard let assetPath = jsonImage else { return }
        
        let result = ImageImportService.relinkEdited(assetPath: assetPath, document: document)
        
        if let error = result.error {
            errorMessage = error
        } else {
            jsonImage = result.assetPath
            errorMessage = nil
        }
    }
    
    private func useOriginalAsEdited() {
        // This functionality is now handled in the Media tab via revert to original
        // For ImageSlotView in BasicInfo/Collection tabs, users should re-import
        errorMessage = "Use the Media tab to revert to the original image."
    }
    
    // MARK: - Remove
    
    private func removeImage() {
        guard let assetPath = jsonImage,
              let assetsFolderURL = document.assetsFolder?.resolvedURL() else {
            jsonImage = nil
            return
        }
        
        // Use ImageImportService to handle deletion
        if let error = ImageImportService.deleteImage(assetPath: assetPath, assetsFolderURL: assetsFolderURL) {
            errorMessage = error
        }
        
        jsonImage = nil
        errorMessage = nil
    }
    
    // MARK: - Permission Helpers
    
    // MARK: - Deprecated: Standalone editor removed
    // Image editing now happens in the Media tab with the inspector panel.
    // The ImageEditorCoordinator and separate window approach has been replaced
    // with integrated editing using ImageCanvasView and MediaInspectorView.
    
    private func updatePermissionState() {
        guard let url = editedURLIfExists else {
            requiresPermission = false
            return
        }
        
        let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path, from: document.documentWrapper)
        ?? (PermissionHelper.isReadable(url) ? url : nil)
        
        requiresPermission = (readableURL == nil)
    }
    
    /// Handle permission errors by prompting the user to grant access
    private func handlePermissionError(for folderURL: URL) {
        guard let assetsFolderPath = document.assetsFolder?.path else { return }
        
        DispatchQueue.main.async {
            let success = AssetFolderManager.shared.requestPermissionForExistingFolder(
                path: assetsFolderPath,
                in: self.$document
            )
            
            if success {
                self.errorMessage = nil
                self.permissionRefreshToken = UUID()
            }
        }
    }
}

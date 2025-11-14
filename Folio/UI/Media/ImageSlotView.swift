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
    ///
    /// Rules:
    /// - thumbnail/icon/banner: use the label's preset aspect.
    /// - poster: if we have an edited image, use its actual orientation. Otherwise use the preset.
    /// - custom: if we have an edited image, use its actual aspect. Otherwise 1:1.
    private var slotAspect: CGFloat {
        if let url = editedURLIfExists,
           let img = NSImage(contentsOf: url),
           img.size.width > 0,
           img.size.height > 0 {
            switch label {
            case .poster, .custom:
                // Orientation-aware: rotated or not, we just trust the image dimensions.
                return img.size.width / img.size.height
            default:
                break
            }
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
        guard let p = jsonImage?.pathToEdited,
              !p.isEmpty,
              FileManager.default.fileExists(atPath: p)
        else { return nil }
        return URL(fileURLWithPath: p)
    }
    
    private var editedPathValue: String? {
        guard let p = jsonImage?.pathToEdited, !p.isEmpty else { return nil }
        return p
    }
    
    private var originalURLIfExists: URL? {
        guard let p = jsonImage?.pathToOriginal,
              !p.isEmpty,
              FileManager.default.fileExists(atPath: p)
        else { return nil }
        return URL(fileURLWithPath: p)
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
                        let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path)
                        ?? (PermissionHelper.isReadable(url) ? url : nil)
                        
                        if let u = readableURL,
                           let img = NSImage(contentsOf: u) {
                            VStack(spacing: 6) {
                                LabeledImagePreview(nsImage: img)
                                    .onTapGesture { openEditorIfPossible() }

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
        
        let panel = NSOpenPanel()
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        
        // If we have a previously stored folder, use it as the starting location only.
        if let existing = document.assetsFolder,
           let existingURL = existing.resolvedURL() {
            panel.directoryURL = existingURL
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            document.assetsFolder = AssetsFolderLocation(url: url)
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
        panel.allowedContentTypes = [.image]
        
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
        guard ensureAssetsFolder(),
              let loc = document.assetsFolder,
              let editedRoot = loc.resolvedURL() else {
            errorMessage = "Select an assets folder first."
            return
        }
        
        // Ensure originals live under assetsRoot/SourceImages
        let sourceImagesFolder = editedRoot.appendingPathComponent("SourceImages", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: sourceImagesFolder,
                withIntermediateDirectories: true
            )
        } catch {
            errorMessage = "Failed to prepare SourceImages folder: \(error.localizedDescription)"
            return
        }
        
        let originalDest = uniqueURL(in: sourceImagesFolder, for: sourceURL.lastPathComponent)
        do {
            if originalDest.standardizedFileURL != sourceURL.standardizedFileURL {
                try FileManager.default.copyItem(at: sourceURL, to: originalDest)
            }
            
            let editedDest = uniqueURL(in: editedRoot, for: suggestedEditedFilename(from: sourceURL))
            
            if let srcImage = NSImage(contentsOf: originalDest) {
                let computedAspect: CGSize
                if case .custom = label {
                    computedAspect = srcImage.size
                } else {
                    computedAspect = label.targetAspect(using: srcImage)
                }
                let maxPixels = label.preferredMaxPixels
                let opts = CoverRenderOptions(
                    targetAspect: computedAspect,
                    targetMaxPixels: maxPixels,
                    output: .jpeg(0.95),
                    enforceCover: true
                )
                if let rendered = CoverRender.renderCover(nsImage: srcImage, options: opts) {
                    let tmp = editedDest.deletingLastPathComponent()
                        .appendingPathComponent(".tmp-\(UUID().uuidString)")
                        .appendingPathExtension(editedDest.pathExtension)
                    try rendered.writeJPEG(to: tmp, quality: 0.95)
                    try SafeFileWriter.atomicReplaceFile(at: editedDest, from: tmp)
                } else {
                    try FileManager.default.copyItem(at: originalDest, to: editedDest)
                }
            } else {
                let editedDest = uniqueURL(
                    in: editedRoot,
                    for: suggestedEditedFilename(from: sourceURL)
                )
                try FileManager.default.copyItem(at: originalDest, to: editedDest)
                jsonImage = AssetPath(
                    pathToOriginal: originalDest.path,
                    pathToEdited: editedDest.path
                )
                errorMessage = nil
                return
            }
            
            jsonImage = AssetPath(
                pathToOriginal: originalDest.path,
                pathToEdited: editedDest.path
            )
            errorMessage = nil
        } catch {
            errorMessage = "Copy to edited folder failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Relink / reuse
    
    private func relinkEdited() {
        guard jsonImage != nil else { return }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if let p = jsonImage?.pathToEdited, !p.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: p).deletingLastPathComponent()
        } else if let o = jsonImage?.pathToOriginal, !o.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: o).deletingLastPathComponent()
        } else if let loc = document.assetsFolder,
                  let root = loc.resolvedURL() {
            panel.directoryURL = root
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            guard let loc = document.assetsFolder,
                  let root = loc.resolvedURL() else {
                errorMessage = "Select an edited images folder first."
                return
            }
            
            let destURL: URL
            if url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path) {
                destURL = url
            } else {
                destURL = uniqueURL(in: root, for: url.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: url, to: destURL)
                } catch {
                    errorMessage = "Copy to edited folder failed: \(error.localizedDescription)"
                    return
                }
            }
            
            var current = jsonImage!
            current.pathToEdited = destURL.path
            jsonImage = current
            errorMessage = nil
        }
    }
    
    private func useOriginalAsEdited() {
        guard var current = jsonImage,
              let loc = document.assetsFolder,
              let root = loc.resolvedURL(),
              let originalURL = originalURLIfExists
        else {
            errorMessage = "Original not available."
            return
        }
        
        let destURL = uniqueURL(in: root, for: suggestedEditedFilename(from: originalURL))
        do {
            try FileManager.default.copyItem(at: originalURL, to: destURL)
            current.pathToEdited = destURL.path
            jsonImage = current
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save edited from original: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Remove
    
    private func removeImage() {
        if let editedPath = jsonImage?.pathToEdited, !editedPath.isEmpty {
            let editedURL = URL(fileURLWithPath: editedPath)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                do {
                    try FileManager.default.removeItem(at: editedURL)
                } catch {
                    errorMessage = "Failed to delete edited image: \(error.localizedDescription)"
                }
            }
        }
        jsonImage = nil
    }
    
    // MARK: - Helpers
    
    private func suggestedEditedFilename(from source: URL) -> String {
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        return "\(label.filenameBase).\(ext)"
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
    
    private func copyOriginalToFolder() {
        guard var current = jsonImage,
              let loc = document.assetsFolder,
              let root = loc.resolvedURL()
        else { return }
        
        let originalURL = URL(fileURLWithPath: current.pathToOriginal)
        
        let sourceImagesFolder = root.appendingPathComponent("SourceImages", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: sourceImagesFolder,
                withIntermediateDirectories: true
            )
        } catch {
            errorMessage = "Failed to prepare SourceImages folder: \(error.localizedDescription)"
            return
        }
        
        let destURL = uniqueURL(in: sourceImagesFolder, for: originalURL.lastPathComponent)
        do {
            if originalURL.standardizedFileURL != destURL.standardizedFileURL {
                try FileManager.default.copyItem(at: originalURL, to: destURL)
            }
            current.pathToOriginal = destURL.path
            jsonImage = current
            errorMessage = nil
        } catch {
            errorMessage = "Copy failed: \(error.localizedDescription)"
        }
    }
    
    private func openEditorIfPossible() {
        guard let edited = editedURLIfExists else { return }
        
        let original: URL
        if let o = originalURLIfExists {
            original = o
        } else if let p = jsonImage?.pathToOriginal, !p.isEmpty {
            original = URL(fileURLWithPath: p)
        } else {
            return
        }
        
        switch label {
        case .thumbnail, .banner, .poster, .icon, .heroBanner:
            ImageEditorCoordinator.openEditor(
                originalURL: original,
                editedURL: edited,
                label: label
            ) {
                if let current = jsonImage { jsonImage = nil; jsonImage = current }
            }
        case .custom:
            ImageEditorCoordinator.openEditorFreeform(
                originalURL: original,
                editedURL: edited
            ) {
                if let current = jsonImage { jsonImage = nil; jsonImage = current }
            }
        }
    }
    
    
    private func updatePermissionState() {
        guard let url = editedURLIfExists else {
            requiresPermission = false
            return
        }
        
        let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path)
        ?? (PermissionHelper.isReadable(url) ? url : nil)
        
        requiresPermission = (readableURL == nil)
    }
}

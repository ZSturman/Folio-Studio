//
//  ImageSlotView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//


// ImageSlotView.swift

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ImageSlotView: View {
    let label: ImageLabel
    @Binding var jsonImage: AssetPath?
    @Binding var assetsFolder: URL?

    @State private var dropIsTargeted = false
    @State private var errorMessage: String?

    private var editedURLIfExists: URL? {
        guard let p = jsonImage?.pathToEdited, !p.isEmpty, FileManager.default.fileExists(atPath: p) else { return nil }
        return URL(fileURLWithPath: p)
    }
    private var editedPathValue: String? {
        guard let p = jsonImage?.pathToEdited, !p.isEmpty else { return nil }
        return p
    }
    private var originalURLIfExists: URL? {
        guard let p = jsonImage?.pathToOriginal, !p.isEmpty, FileManager.default.fileExists(atPath: p) else { return nil }
        return URL(fileURLWithPath: p)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.title)
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(dropIsTargeted ? .accentColor : .secondary)
                    .frame(height: 200)

                Group {
                    
                    if let url = editedURLIfExists {
                        let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path) ?? (PermissionHelper.isReadable(url) ? url : nil)
                        if let u = readableURL, let img = NSImage(contentsOf: u) {
                            VStack(spacing: 6) {
                                LabeledImagePreview(nsImage: img)
                                    .onTapGesture { openEditorIfPossible() }
                            }
                        } else {
                            PermissionRequiredRow(title: label.title, url: url) { granted in
                                print("Permission granted for \(url.path)")
                            }
                        }
                    
                    

                    } else if let editedValue = editedPathValue, !editedValue.isEmpty {
                        VStack(spacing: 10) {
                            Text("Edited image not found")
                                .font(.subheadline).foregroundColor(.primary)
                            Text(editedValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            HStack(spacing: 8) {
                                Button("Relink Edited…") { relinkEdited() }
                                Button("Use Original as Edited") { useOriginalAsEdited() }
                                    .disabled(originalURLIfExists == nil || assetsFolder == nil)
                                Button("Clear") { removeImage() }
                            }
                        }
                        .padding()
                    } else {
                        VStack(spacing: 6) {
                            Text("Drop image or GIF here")
                                .font(.subheadline)
                            Text("or")
                            Button("Import…") { importViaDialog() }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $dropIsTargeted) { providers in
                handleDrop(providers: providers)
            }

            if let img = jsonImage {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Original:").bold()
                        Text(img.pathToOriginal).lineLimit(1).truncationMode(.middle)
                    }.font(.caption)
                    HStack {
                        Text("Edited:").bold()
                        Text(img.pathToEdited).lineLimit(1).truncationMode(.middle)
                    }.font(.caption)
                }
            }

            HStack(spacing: 8) {
                Button("Import…") { importViaDialog() }
                Button("Copy Original") { copyOriginalToFolder() }
                    .disabled(jsonImage == nil)
                Button("Remove") { removeImage() }
                    .disabled(jsonImage == nil)
                Spacer()
            }

            if let msg = errorMessage {
                Text(msg).foregroundColor(.red).font(.caption)
            }
        }
    }

    // MARK: - Import

    private func importViaDialog() {
        guard assetsFolder != nil else {
            errorMessage = "Select an edited images folder first."
            return
        }
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
        guard assetsFolder != nil else {
            errorMessage = "Select an edited images folder first."
            return false
        }
        if let fileProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
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
        guard let editedRoot = assetsFolder else { return }
        let destURL = uniqueURL(in: editedRoot, for: suggestedEditedFilename(from: sourceURL))
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            if let srcImage = NSImage(contentsOf: sourceURL) {
                let targetAspect = label.targetAspect(using: srcImage)
                let maxPixels = label.preferredMaxPixels
                let opts = CoverRenderOptions(
                    targetAspect: targetAspect,
                    targetMaxPixels: maxPixels,
                    output: .jpeg(0.95),
                    enforceCover: true
                )
                if let rendered = CoverRender.renderCover(nsImage: srcImage, options: opts) {
                    let tmp = destURL.deletingLastPathComponent().appendingPathComponent(".tmp-\(UUID().uuidString)").appendingPathExtension(destURL.pathExtension)
                    try rendered.writeJPEG(to: tmp, quality: 0.95)
                    try SafeFileWriter.atomicReplaceFile(at: destURL, from: tmp)
                }
            }
            jsonImage = AssetPath(pathToOriginal: sourceURL.path, pathToEdited: destURL.path)
            errorMessage = nil
        } catch {
            errorMessage = "Copy to edited folder failed: \(error.localizedDescription)"
        }
    }

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
        } else if let root = assetsFolder {
            panel.directoryURL = root
        }
        if panel.runModal() == .OK, let url = panel.url {
            var current = jsonImage!
            current.pathToEdited = url.path
            jsonImage = current
            errorMessage = nil
        }
    }

    private func useOriginalAsEdited() {
        guard var current = jsonImage, let root = assetsFolder, let originalURL = originalURLIfExists else {
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
                do { try FileManager.default.removeItem(at: editedURL) }
                catch { errorMessage = "Failed to delete edited image: \(error.localizedDescription)" }
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
            let newName = "\(base) copy\(index == 1 ? "" : " \(index)")" + (ext.isEmpty ? "" : ".\(ext)")
            candidate = folder.appendingPathComponent(newName)
            index += 1
        }
        return candidate
    }
    
        private func copyOriginalToFolder() {
            guard var current = jsonImage, let root = assetsFolder else { return }
            let originalURL = URL(fileURLWithPath: current.pathToOriginal)
    
            // Create `SourceImages` subfolder inside the assets folder if needed
            let sourceImagesFolder = root.appendingPathComponent("SourceImages", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: sourceImagesFolder, withIntermediateDirectories: true)
            } catch {
                errorMessage = "Failed to prepare SourceImages folder: \(error.localizedDescription)"
                return
            }
    
            // Preserve the original filename when copying the original
            let destURL = uniqueURL(in: sourceImagesFolder, for: originalURL.lastPathComponent)
            do {
                // If the original path is already inside SourceImages with the same resolved path, skip
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
        case .thumbnail, .banner, .poster, .icon:
            ImageEditorCoordinator.openEditor(originalURL: original, editedURL: edited, label: label) {
                if let current = jsonImage { jsonImage = nil; jsonImage = current }
            }
        case .custom:
            ImageEditorCoordinator.openEditorFreeform(originalURL: original, editedURL: edited) {
                if let current = jsonImage { jsonImage = nil; jsonImage = current }
            }
        }
    }
}

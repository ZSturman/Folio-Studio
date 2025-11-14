//
//  MediaDetailView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//

import SwiftUI


struct MediaDetailView: View {
    @Binding var document: FolioDocument
    @State private var errorMessage: String?
    @Binding var selectedImageLabel: ImageLabel
    @State private var editedLabelName: String = ""

    private var jsonImage: AssetPath? {
        document.images[selectedImageLabel]
    }

    private var isCustomSelectedLabel: Bool {
        if case .custom = selectedImageLabel {
            return true
        }
        return false
    }

    private var canShowCopyOriginalButton: Bool {
        guard let current = jsonImage,
              !current.pathToOriginal.isEmpty,
              let loc = document.assetsFolder,
              let root = loc.resolvedURL()
        else {
            return false
        }

        let originalURL = URL(fileURLWithPath: current.pathToOriginal)
        let sourceImagesFolder = root.appendingPathComponent("SourceImages", isDirectory: true)
        let destURL = uniqueURL(in: sourceImagesFolder, for: originalURL.lastPathComponent)

        return destURL.standardizedFileURL.path != originalURL.standardizedFileURL.path
    }

    private func setJsonImage(_ newValue: AssetPath?) {
        document.images[selectedImageLabel] = newValue
    }

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
        setJsonImage(nil)
        
        if document.images[selectedImageLabel] == nil {
            if let firstKey = document.images.keys.sorted().first {
                selectedImageLabel = ImageLabel(storageKey: firstKey)
            } else {
                selectedImageLabel = .thumbnail
            }
        }
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
            // You can log this error if desired
            return
        }

        let destURL = uniqueURL(in: sourceImagesFolder, for: originalURL.lastPathComponent)
        do {
            if originalURL.standardizedFileURL != destURL.standardizedFileURL {
                try FileManager.default.copyItem(at: originalURL, to: destURL)
            }
            current.pathToOriginal = destURL.path
            setJsonImage(current)
        } catch {
            // You can log this error if desired
        }
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

    private var isCurrentAssetEmpty: Bool {
        guard let asset = jsonImage else { return true }
        return asset.pathToOriginal.isEmpty && asset.pathToEdited.isEmpty
    }
    
    private func clearImageButKeepKey() {
        guard var current = jsonImage else { return }
        
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
        
        current.pathToOriginal = ""
        current.pathToEdited = ""
        setJsonImage(current)
    }
    
    private func applyLabelEdit() {
        let trimmed = editedLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard case .custom = selectedImageLabel else { return }
        
        let oldLabel = selectedImageLabel
        let newLabel: ImageLabel = .custom(trimmed)
        if newLabel == oldLabel { return }
        
        let existing = document.images[oldLabel]
        document.images[oldLabel] = nil
        document.images[newLabel] = existing
        selectedImageLabel = newLabel
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ImageSlotView(
                label: selectedImageLabel,
                jsonImage: Binding(
                    get: { document.images[selectedImageLabel] },
                    set: { document.images[selectedImageLabel] = $0 }
                ),
                document: $document,
                labelPrefix: Binding<String>(
                    get: { document.title },
                    set: { document.title = $0 }
                )
            )
            .frame(maxWidth: 260, maxHeight: 260)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Label", text: $editedLabelName)
                    .disabled(!isCustomSelectedLabel)

                HStack(spacing: 8) {
                    Button("Edit Label") {
                        applyLabelEdit()
                    }
                    .disabled(
                        !isCustomSelectedLabel ||
                        editedLabelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        editedLabelName == selectedImageLabel.title
                    )

                    if isCustomSelectedLabel {
                        Button("Remove Image") {
                            clearImageButKeepKey()
                        }
                        .disabled(isCurrentAssetEmpty)
                    }

                    if canShowCopyOriginalButton {
                        Button("Copy Original") {
                            copyOriginalToFolder()
                        }
                        .disabled(jsonImage == nil)
                    }
                }
                Button(role: .destructive) {
                    removeImage()
                } label: {
                    Text("Delete Image Key")
                }
                .disabled(document.images[selectedImageLabel] == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            editedLabelName = selectedImageLabel.title
        }
        .onChange(of: selectedImageLabel) {
            editedLabelName = selectedImageLabel.title
        }
    }
}

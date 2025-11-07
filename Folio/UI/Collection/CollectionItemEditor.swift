//
//  CollectionItemEditor.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import QuickLookThumbnailing




/// Dedicated thumbnail preview row that accepts an NSImage directly.
private struct ThumbnailPreviewRow: View {
    let image: NSImage
    let title: String
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .lineLimit(1)
                Text("Thumbnail preview")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(role: .destructive) { onDelete() } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct CollectionItemEditor: View {
    @Binding var document: FolioDocument
    @Binding var item: JSONCollectionItem

    let collectionName: String
    let assetsFolder: URL?
    var onDelete: () -> Void

    @State private var errorMessage: String?
    @State private var isDropTargetedFile = false
    @State private var isDropTargetedThumb = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Item label", text: $item.label)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onChange(of: item.label) { old, new in
                        guard let assets = assetsFolder else { return }
                        let colFolder = CollectionFS.collectionsRoot(in: assets).appendingPathComponent(CollectionFS.safeName(collectionName), isDirectory: true)
                        do {
                            let newFolder = try CollectionFS.renameItemFolder(collectionFolder: colFolder, oldLabel: old, newLabel: new)
                            // Rebase edited file
                            item.filePath.pathToEdited = CollectionFS.rebaseEditedPath(
                                oldEditedPath: item.filePath.pathToEdited,
                                oldParent: colFolder.appendingPathComponent(CollectionFS.safeName(old), isDirectory: true),
                                newParent: newFolder
                            )
                            // Rebase thumbnail
                            item.thumbnail.pathToEdited = CollectionFS.rebaseEditedPath(
                                oldEditedPath: item.thumbnail.pathToEdited,
                                oldParent: colFolder.appendingPathComponent(CollectionFS.safeName(old), isDirectory: true),
                                newParent: newFolder
                            )
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }

                Spacer()

                Menu {
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete Item", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            TextEditor(text: Binding(get: { item.summary ?? "" }, set: { item.summary = $0 }))
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)))
                .padding(.trailing, 4)

            // Original file picker + copy
            VStack(alignment: .leading, spacing: 8) {
                Text("File").font(.subheadline).bold()

                if let url = previewURL(for: item.filePath.pathToOriginal, edited: item.filePath.pathToEdited) {
                    // If unreadable, let the user grant permission rather than reverting to drop target.
                    if PermissionHelper.isReadable(url) || PermissionHelper.resolvedURL(forOriginalPath: url.path) != nil {
                        let effectiveURL = PermissionHelper.resolvedURL(forOriginalPath: url.path) ?? url
                        let preloaded = NSImage(contentsOf: effectiveURL)
                        FilePreviewRow(url: effectiveURL, title: "File", preloadedImage: preloaded) {
                            removeItemFile()
                        }
                    } else {
                        PermissionRequiredRow(title: "File", url: url) { granted in
                            // Prefer to point to the exact granted URL for future reads
                            if item.filePath.pathToEdited.isEmpty {
                                item.filePath.pathToOriginal = granted.path
                            } else {
                                item.filePath.pathToEdited = granted.path
                            }
                        }
                    }
                } else {
                    DropTargetView(
                        isTargeted: $isDropTargetedFile,
                        title: "Drag a file here or click to browse"
                    ) { url in
                        item.filePath.pathToOriginal = url.path
                    }
                    .onTapGesture { pickFileForOriginal() }
                }

                if !item.filePath.pathToOriginal.isEmpty {
                    LabeledContent("Original") { Text(item.filePath.pathToOriginal).font(.footnote).textSelection(.enabled) }
                }
                if !item.filePath.pathToEdited.isEmpty {
                    LabeledContent("Edited") { Text(item.filePath.pathToEdited).font(.footnote).textSelection(.enabled) }
                }

                HStack {
                    Button {
                        copyOriginalIntoAssets()
                    } label: {
                        Label("Copy to assets folder", systemImage: "arrow.down.doc")
                    }
                    .disabled(!(assetsFolder != nil && !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !item.filePath.pathToOriginal.isEmpty))

                    Spacer()
                }
            }


            // Thumbnail picker (always copied)
            VStack(alignment: .leading, spacing: 8) {
                Text("Thumbnail").font(.subheadline).bold()

                if let url = previewURL(for: item.thumbnail.pathToOriginal, edited: item.thumbnail.pathToEdited) {
                    let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path) ?? (PermissionHelper.isReadable(url) ? url : nil)
                    if let u = readableURL, let img = NSImage(contentsOf: u) {
                        VStack(spacing: 6) {
                            ThumbnailPreviewRow(image: img, title: "Thumbnail") {
                                removeThumbnail()
                            }
                        }
                    } else {
                        PermissionRequiredRow(title: "Thumbnail", url: url) { granted in
                            // Always copy thumbnails into assets after permission is granted.
                            copyThumbnailIntoAssets(from: granted)
                        }
                    }
                } else {
                    DropTargetView(
                        isTargeted: $isDropTargetedThumb,
                        title: "Drop thumbnail image or click to browse",
                        acceptImagesOnly: true
                    ) { url in
                        copyThumbnailIntoAssets(from: url)
                    }
                    .onTapGesture { pickImageForThumbnail() }
                }

                if !item.thumbnail.pathToOriginal.isEmpty {
                    LabeledContent("Source") { Text(item.thumbnail.pathToOriginal).font(.footnote).textSelection(.enabled) }
                }
                if !item.thumbnail.pathToEdited.isEmpty {
                    LabeledContent("Copied") { Text(item.thumbnail.pathToEdited).font(.footnote).textSelection(.enabled) }
                }
            }

            // Optional: Resource picker
            DisclosureGroup("Resource") {
                ResourcePickerView(resource: $item.resource, currentDocumentURL: nil)
                    .padding(.top, 6)
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
    }

    // MARK: File helpers
    private func previewURL(for original: String, edited: String) -> URL? {
        if !edited.isEmpty { return URL(fileURLWithPath: edited) }
        if !original.isEmpty { return URL(fileURLWithPath: original) }
        return nil
    }

    private func removeItemFile() {
        // Delete edited file if it exists on disk
        if !item.filePath.pathToEdited.isEmpty {
            let fm = FileManager.default
            let p = item.filePath.pathToEdited
            if fm.fileExists(atPath: p) { try? fm.removeItem(atPath: p) }
        }
        // Clear both paths to restore drop UI
        item.filePath.pathToOriginal = ""
        item.filePath.pathToEdited = ""
    }

    private func removeThumbnail() {
        if !item.thumbnail.pathToEdited.isEmpty {
            let fm = FileManager.default
            let p = item.thumbnail.pathToEdited
            if fm.fileExists(atPath: p) { try? fm.removeItem(atPath: p) }
        }
        item.thumbnail.pathToOriginal = ""
        item.thumbnail.pathToEdited = ""
    }

    // MARK: Actions

    private func pickFileForOriginal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            item.filePath.pathToOriginal = url.path
        }
    }

    private func pickImageForThumbnail() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            copyThumbnailIntoAssets(from: url)
        }
    }

    private func copyOriginalIntoAssets() {
        guard let assets = assetsFolder else { return }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !item.filePath.pathToOriginal.isEmpty else { return }
        do {
            let colFolder = try CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: collectionName)
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: item.label)
            let src = URL(fileURLWithPath: item.filePath.pathToOriginal)
            let copied = try CollectionFS.copyWithCollision(from: src, to: itemFolder)
            item.filePath.pathToEdited = copied.path
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyThumbnailIntoAssets(from src: URL) {
        guard let assets = assetsFolder else { return }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let colFolder = try CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: collectionName)
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: item.label)
            // Force filename "thumbnail" with same extension if possible
            let ext = src.pathExtension.isEmpty ? "png" : src.pathExtension
            let dest = itemFolder.appendingPathComponent("thumbnail").appendingPathExtension(ext)
            let fm = FileManager.default
            if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
            try fm.copyItem(at: src, to: dest)

            item.thumbnail.pathToOriginal = src.path
            item.thumbnail.pathToEdited = dest.path
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

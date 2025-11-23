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
import SwiftData
// Import CollectionItemType from JSONCollectionItem.swift




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

    @Environment(\.modelContext) private var modelContext

    // Projects for Folio localLink flow
    @Query(sort: [SortDescriptor(\ProjectDoc.title, order: .forward)])
    private var allProjects: [ProjectDoc]

    let collectionName: String
    let assetsFolder: URL?
    var onDelete: () -> Void

    @State private var errorMessage: String?
    @State private var isDropTargetedFile = false
    @State private var isDropTargetedThumb = false
    @State private var showPrivateProjects = false
    @State private var localType: CollectionItemType

    init(document: Binding<FolioDocument>,
         item: Binding<JSONCollectionItem>,
         collectionName: String,
         assetsFolder: URL?,
         onDelete: @escaping () -> Void) {
        self._document = document
        self._item = item
        self.collectionName = collectionName
        self.assetsFolder = assetsFolder
        self.onDelete = onDelete
        _localType = State(initialValue: item.wrappedValue.type)
    }


    private var urlBinding: Binding<String> {
        Binding<String>(
            get: { item.url ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    item.url = nil
                    // Do not automatically change type if URL cleared
                } else {
                    item.url = trimmed
                    // Enforce urlLink type and drop any local file reference
                    item.type = .urlLink
                    item.filePath = nil
                }
            }
        )
    }
    
    private var fileSourceBinding: Binding<CollectionItemType> {
        Binding<CollectionItemType>(
            get: {
                localType
            },
            set: { newValue in
                localType = newValue
                item.type = newValue
                switch newValue {
                case .file:
                    // Switch to file: clear URL, keep file
                    item.url = nil
                    // Do not clear filePath, keep as-is
                case .urlLink:
                    // Switch to URL link: clear filePath
                    item.filePath = nil
                case .folio:
                    // Switch to Folio: clear both filePath and URL for now
                    item.filePath = nil
                    item.url = nil
                }
            }
        )
    }
    
    private var itemSummaryBinding: Binding<String> {
        Binding(
            get: { item.summary ?? "" },
            set: { item.summary = $0 }
        )
    }

    // Project list for localLink/.folio
    private var filteredProjects: [ProjectDoc] {
        if showPrivateProjects { return allProjects }
        return allProjects.filter { $0.isPublic }
    }

    private func projectIdString(_ p: ProjectDoc) -> String {
        let mirror = Mirror(reflecting: p)
        if let idChild = mirror.children.first(where: { $0.label == "id" }) {
            if let uuidValue = idChild.value as? UUID {
                return uuidValue.uuidString
            }
            if let strValue = idChild.value as? String {
                return strValue
            }
        }
        return String(describing: p)
    }

    private func ensureAssetsFolder() -> URL? {
        // 1. If the document already has an assets folder location, try to resolve it
        if let loc = document.assetsFolder, let resolved = loc.resolvedURL() {
            return resolved
        }

        // 2. Use AssetFolderManager to prompt user for folder selection
        return AssetFolderManager.shared.ensureAssetsFolder(for: $document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: thumbnail on the left, label on the right
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail picker (always copied)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thumbnail")
                        .font(.subheadline)
                        .bold()

                    if let url = previewURL(for: item.thumbnail.pathToOriginal ?? "", edited: item.thumbnail.pathToEdited ?? "") {
                        let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path, from: document.documentWrapper)
                            ?? (PermissionHelper.isReadable(url) ? url : nil)
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
                }
                .frame(maxWidth: 220)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Item label", text: $item.label)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                        .onChange(of: item.label) { old, new in
                            guard let assets = ensureAssetsFolder() else { return }
                            let colFolder = CollectionFS.collectionsRoot(in: assets)
                                .appendingPathComponent(CollectionFS.safeName(collectionName), isDirectory: true)
                            do {
                                let oldLabel = old
                                let newLabel = new
                                let oldFolder = colFolder.appendingPathComponent(CollectionFS.safeName(oldLabel), isDirectory: true)
                                let newFolder = try CollectionFS.renameItemFolder(collectionFolder: colFolder,
                                                                                  oldLabel: oldLabel,
                                                                                  newLabel: newLabel)
                                // Rebase edited file, if present
                                if var fp = item.filePath {
                                    fp.pathToEdited = CollectionFS.rebaseEditedPath(
                                        oldEditedPath: fp.pathToEdited ?? "",
                                        oldParent: oldFolder,
                                        newParent: newFolder
                                    )
                                    item.filePath = fp
                                }
                                // Rebase thumbnail
                                item.thumbnail.pathToEdited = CollectionFS.rebaseEditedPath(
                                    oldEditedPath: item.thumbnail.pathToEdited ?? "",
                                    oldParent: oldFolder,
                                    newParent: newFolder
                                )
                                errorMessage = nil
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                }

                Spacer()
            }

            // Summary, styled similarly to BasicInfoTabView
            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if itemSummaryBinding.wrappedValue.isEmpty {
                        Text("Write a short overview of this item...")
                            .foregroundStyle(.secondary)
                            .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
                    }

                    TextEditor(text: itemSummaryBinding)
                        .frame(minHeight: 100)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.quaternary)
                )
            }
            .padding(.trailing, 4)

            // Original file picker + copy
            VStack(alignment: .leading, spacing: 8) {
                
                HStack {
                    Text("File").font(.subheadline).bold()
                    Spacer()
                    Picker("Source", selection: fileSourceBinding) {
                        Text("File").tag(CollectionItemType.file)
                        Text("URL").tag(CollectionItemType.urlLink)
                        Text("Folio").tag(CollectionItemType.folio)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
                
                Group {
                    switch item.type {
                    case .file:
                        if let url = previewURL(for: item.filePath?.pathToOriginal ?? "", edited: item.filePath?.pathToEdited ?? "") {
                            // If unreadable, let the user grant permission rather than reverting to drop target.
                            if PermissionHelper.isReadable(url) || PermissionHelper.resolvedURL(forOriginalPath: url.path, from: document.documentWrapper) != nil {
                                let effectiveURL = PermissionHelper.resolvedURL(forOriginalPath: url.path, from: document.documentWrapper) ?? url
                                let preloaded = NSImage(contentsOf: effectiveURL)
                                FilePreviewRow(url: effectiveURL, title: "File", preloadedImage: preloaded) {
                                    removeItemFile()
                                }
                            } else {
                                PermissionRequiredRow(title: "File", url: url) { granted in
                                    // Prefer to point to the exact granted URL for future reads
                                    if var fp = item.filePath {
                                        if (fp.pathToEdited ?? "").isEmpty {
                                            fp.pathToOriginal = granted.path
                                        } else {
                                            fp.pathToEdited = granted.path
                                        }
                                        item.filePath = fp
                                    } else {
                                        var fp = AssetPath()
                                        fp.pathToOriginal = granted.path
                                        item.filePath = fp
                                    }
                                    item.type = .file
                                    item.url = nil
                                }
                            }
                        } else {
                            DropTargetView(
                                isTargeted: $isDropTargetedFile,
                                title: "Drag a file here or click to browse"
                            ) { url in
                                var fp = item.filePath ?? AssetPath()
                                fp.pathToOriginal = url.path
                                item.filePath = fp
                                item.type = .file
                                item.url = nil
                            }
                            .onTapGesture { pickFileForOriginal() }
                        }
                        
                        if let fp = item.filePath, !(fp.pathToOriginal ?? "").isEmpty {
                            LabeledContent("Original") { Text(fp.pathToOriginal ?? "").font(.footnote).textSelection(.enabled) }
                        }
                        if let fp = item.filePath, !(fp.pathToEdited ?? "").isEmpty {
                            LabeledContent("Edited") { Text(fp.pathToEdited ?? "").font(.footnote).textSelection(.enabled) }
                        }
                        
                        // Auto-copy happens on selection now
                    case .urlLink:
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("https://example.com", text: urlBinding)
                                .textFieldStyle(.roundedBorder)
                            if let urlString = item.url, !urlString.isEmpty {
                                Text(urlString)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    case .folio:
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Folio Project")
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                                Picker("Project", selection: Binding(
                                    get: {
                                        filteredProjects
                                            .first(where: { projectIdString($0) == (item.url ?? "") })
                                            .map { projectIdString($0) } ?? ""
                                    },
                                    set: { newValue in
                                        item.url = newValue.isEmpty ? nil : newValue
                                    })
                                ) {
                                    if filteredProjects.isEmpty {
                                        Text("None").tag("")
                                    } else {
                                        ForEach(filteredProjects, id: \.self) { p in
                                            Text(p.title).tag(projectIdString(p))
                                        }
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: 260)
                            }
                            
                            Toggle("Show private projects", isOn: $showPrivateProjects)
                                .toggleStyle(.switch)
                            
                            if showPrivateProjects {
                                Text("Warning: selecting a private project may cause downstream access issues.")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                            
                            if let selectedId = item.url,
                               let project = filteredProjects.first(where: { projectIdString($0) == selectedId }) {
                                LabeledContent("Selected") {
                                    Text(project.title)
                                        .font(.footnote)
                                        .textSelection(.enabled)
                                }
                            
                        }
                    }
                }
            }
            .id(item.type.rawValue) // Force view refresh when type changes
                
            ResourcePickerView(resource: $item.resource, document: $document)
                .padding(.top, 6)
                .id("\(item.resource.category)-\(item.resource.type)") // Force refresh when category/type changes
                
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete Item", systemImage: "trash")
            }
                
                
                if let err = errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
            .onAppear {
                let currentType = item.type
                if currentType == .folio,
                   (item.url ?? "").isEmpty,
                   let first = filteredProjects.first {
                    item.url = projectIdString(first)
                }
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
        if let edited = item.filePath?.pathToEdited, !edited.isEmpty {
            let fm = FileManager.default
            if fm.fileExists(atPath: edited) { try? fm.removeItem(atPath: edited) }
        }
        // Clear file reference entirely
        item.filePath = nil
        if item.type == .file {
            item.type = .file // keep as file, but with no file attached
        }
    }

    private func removeThumbnail() {
        if let p = item.thumbnail.pathToEdited, !p.isEmpty {
            let fm = FileManager.default
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
            // Auto-set label if empty
            if item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item.label = url.deletingPathExtension().lastPathComponent
            }
            
            var fp = item.filePath ?? AssetPath()
            fp.pathToOriginal = url.path
            fp.pathToEdited = ""
            item.filePath = fp
            item.type = .file
            item.url = nil
            
            // Auto-copy to assets immediately
            copyOriginalIntoAssets()
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
        guard let assets = ensureAssetsFolder() else { return }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let fp = item.filePath, let originalPath = fp.pathToOriginal, !originalPath.isEmpty else { return }
        do {
            let colFolder = try CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: collectionName)
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: item.label)
            let src = URL(fileURLWithPath: originalPath)
            let copied = try CollectionFS.copyWithCollision(from: src, to: itemFolder)

            var newFP = fp
            newFP.pathToEdited = copied.path
            item.filePath = newFP
            item.type = .file
            item.url = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyThumbnailIntoAssets(from src: URL) {
        guard let assets = ensureAssetsFolder() else { return }
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

// MARK: - AssetsFolderLocation helpers
extension AssetsFolderLocation {
    init(url: URL) {
        self.path = url.path
        // Bookmark data no longer stored here - managed by BookmarkManager
    }

    /// Resolve to a usable URL using BookmarkManager
    /// - Parameter documentWrapper: The document's FileWrapper containing bookmarks
    func resolvedURL(from documentWrapper: FileWrapper? = nil) -> URL? {
        guard let path = path else { return nil }
        
        // Try BookmarkManager first if wrapper provided
        if let wrapper = documentWrapper,
           let resolved = BookmarkManager.shared.resolve(path: path, from: wrapper) {
            return resolved
        }
        
        // Fallback to direct path
        return URL(fileURLWithPath: path)
    }
}

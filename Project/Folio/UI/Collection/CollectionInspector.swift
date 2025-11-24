//
//  CollectionInspector.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Inspector panel for editing a selected CollectionItem.
/// Displays in a trailing sidebar, auto-opens on item selection.
struct CollectionInspector: View {
    @ObservedObject var viewModel: CollectionViewModel
    @Binding var document: FolioDocument
    
    @Environment(\.modelContext) private var modelContext
    
    // Projects for Folio localLink flow
    @Query(sort: [SortDescriptor(\ProjectDoc.title, order: .forward)])
    private var allProjects: [ProjectDoc]
    
    let assetsFolder: URL?
    
    @State private var errorMessage: String?
    @State private var isDropTargetedFile = false
    @State private var isDropTargetedThumb = false
    @State private var showPrivateProjects = false
    
    // Local state for debouncing text fields
    @State private var editingLabel: String = ""
    @State private var editingSummary: String = ""
    @State private var editingUrl: String = ""
    @State private var inspectorType: CollectionItemType = .file
    
    @State private var thumbnailRefreshKey: UUID = UUID()
    @FocusState private var labelFieldFocused: Bool
    @FocusState private var summaryFieldFocused: Bool
    
    // Debounce timers
    @State private var labelDebounceTimer: Timer?
    @State private var summaryDebounceTimer: Timer?
    
    // Computed Binding to the selected item
    private var selectedItemBinding: Binding<JSONCollectionItem>? {
        guard let collectionName = viewModel.selectedCollectionName,
              let itemId = viewModel.selectedItemId,
              document.collection[collectionName] != nil
        else { return nil }

        return Binding(
            get: {
                guard let section = self.document.collection[collectionName],
                      let index = section.items.firstIndex(where: { $0.id == itemId }) else {
                    return JSONCollectionItem() // Fallback - should not happen
                }
                return section.items[index]
            },
            set: { newValue in
                guard var section = self.document.collection[collectionName],
                      let index = section.items.firstIndex(where: { $0.id == itemId }) else {
                    return
                }
                section.items[index] = newValue
                self.document.collection[collectionName] = section
                self.document.updatedAt = Date()
            }
        )
    }
    
    var body: some View {
        ScrollView {
            if let itemBinding = selectedItemBinding {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    
                    thumbnailSection(item: itemBinding)
                    
                    labelSection(item: itemBinding)
                    
                    summarySection(item: itemBinding)
                    
                    fileSourceSection(item: itemBinding)
                    
                    resourceSection(item: itemBinding)
                    
                    deleteSection
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                .id(itemBinding.wrappedValue.id)
                .onAppear {
                    syncLocalState(from: itemBinding.wrappedValue)
                }
                .onChange(of: itemBinding.wrappedValue.id) { _, newId in
                    // When selection changes, sync local state
                    syncLocalState(from: itemBinding.wrappedValue)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No Item Selected")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Select an item to view details")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            Text("Item Details")
                .font(.headline)
            Spacer()
            Button {
                viewModel.deselectItem()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func thumbnailSection(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thumbnail")
                .font(.subheadline)
                .bold()
            
            ThumbnailContentView(
                item: item,
                document: document,
                isDropTargeted: $isDropTargetedThumb,
                onCopyThumbnail: { url in copyThumbnailIntoAssets(from: url, item: item) },
                onPickImage: { pickImageForThumbnail(item: item) },
                onRemoveThumbnail: { removeThumbnail(item: item) }
            )
            .id(thumbnailRefreshKey)
        }
    }
    
    private func labelSection(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Label")
                .font(.subheadline)
                .bold()
            
            TextField("Item label", text: $editingLabel, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($labelFieldFocused)
                .onSubmit {
                    labelDebounceTimer?.invalidate()
                    commitLabel(to: item)
                }
                .onChange(of: editingLabel) { _, _ in
                    labelDebounceTimer?.invalidate()
                    labelDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
                        commitLabel(to: item)
                    }
                }
                .onChange(of: labelFieldFocused) { _, isFocused in
                    if !isFocused {
                        labelDebounceTimer?.invalidate()
                        commitLabel(to: item)
                    }
                }
        }
    }
    
    private func summarySection(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary")
                .font(.subheadline)
                .bold()
            
            ZStack(alignment: .topLeading) {
                if editingSummary.isEmpty {
                    Text("Write a short overview...")
                        .foregroundStyle(.secondary)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
                }
                
                TextEditor(text: $editingSummary)
                    .frame(minHeight: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .focused($summaryFieldFocused)
                    .onChange(of: editingSummary) { _, _ in
                        summaryDebounceTimer?.invalidate()
                        summaryDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            commitSummary(to: item)
                        }
                    }
                    .onChange(of: summaryFieldFocused) { _, isFocused in
                        if !isFocused {
                            summaryDebounceTimer?.invalidate()
                            commitSummary(to: item)
                        }
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )
        }
    }
    
    private func fileSourceSection(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Source")
                    .font(.subheadline)
                    .bold()
                Spacer()
                Picker("Source", selection: $inspectorType) {
                    Text("File").tag(CollectionItemType.file)
                    Text("URL").tag(CollectionItemType.urlLink)
                    Text("Folio").tag(CollectionItemType.folio)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Group {
                switch inspectorType {
                case .file:
                    fileTypeContent(item: item)
                case .urlLink:
                    urlTypeContent(item: item)
                case .folio:
                    folioTypeContent(item: item)
                }
            }
        }
    }
    
    private func fileTypeContent(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FileSourceContentView(
                item: item,
                document: document,
                isDropTargeted: $isDropTargetedFile,
                onPickFile: { pickFileForOriginal(item: item) },
                onRemoveFile: { removeItemFile(item: item) }
            )
            
            if let fp = item.wrappedValue.filePath, !(fp.pathToOriginal?.isEmpty ?? true) {
                LabeledContent("Original") {
                    Text(fp.pathToOriginal ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            if let fp = item.wrappedValue.filePath, !(fp.pathToEdited?.isEmpty ?? true) {
                LabeledContent("Edited") {
                    Text(fp.pathToEdited ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            
            Button {
                copyOriginalIntoAssets(item: item)
            } label: {
                Label("Copy to assets", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.bordered)
            .disabled(item.wrappedValue.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (item.wrappedValue.filePath?.pathToOriginal ?? "").isEmpty)
        }
    }
    
    private func urlTypeContent(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("https://example.com", text: Binding(
                get: { item.wrappedValue.url ?? "" },
                set: { newValue in
                    editingUrl = newValue
                    item.wrappedValue.url = newValue.isEmpty ? nil : newValue
                    if !newValue.isEmpty {
                        item.wrappedValue.type = .urlLink
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)
            
            if let urlString = item.wrappedValue.url, !urlString.isEmpty {
                Text(urlString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }
    
    private func folioTypeContent(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Project", selection: Binding(
                get: {
                    let currentUrl = item.wrappedValue.url ?? ""
                    return filteredProjects
                        .first(where: { projectIdString($0) == currentUrl })
                        .map { projectIdString($0) } ?? ""
                },
                set: { newValue in
                    item.wrappedValue.url = newValue.isEmpty ? nil : newValue
                    if !newValue.isEmpty {
                        item.wrappedValue.type = .folio
                    }
                }
            )) {
                Text("Select a project...").tag("")
                if !filteredProjects.isEmpty {
                    ForEach(filteredProjects, id: \.persistentModelID) { p in
                        Text(p.title).tag(projectIdString(p))
                    }
                }
            }
            .pickerStyle(.menu)
            
            Toggle("Show private projects", isOn: $showPrivateProjects)
                .toggleStyle(.switch)
            
            if showPrivateProjects {
                Text("Warning: selecting a private project may cause downstream access issues.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            if let selectedId = item.wrappedValue.url,
               let project = filteredProjects.first(where: { projectIdString($0) == selectedId }) {
                LabeledContent("Selected") {
                    Text(project.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private func resourceSection(item: Binding<JSONCollectionItem>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resource")
                .font(.subheadline)
                .bold()
            
            ResourcePickerView(
                resource: item.resource,
                document: $document
            )
        }
    }
    
    private var deleteSection: some View {
        Button(role: .destructive) {
            viewModel.deleteItem(document: $document)
        } label: {
            Label("Delete Item", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
    
    // MARK: - Helpers
    
    private func syncLocalState(from item: JSONCollectionItem) {
        labelDebounceTimer?.invalidate()
        summaryDebounceTimer?.invalidate()
        
        editingLabel = item.label
        editingSummary = item.summary ?? ""
        editingUrl = item.url ?? ""
        inspectorType = item.type
    }
    
    private func commitLabel(to item: Binding<JSONCollectionItem>) {
        let trimmed = editingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingLabel = item.wrappedValue.label
            return
        }
        
        if trimmed != item.wrappedValue.label {
            let oldLabel = item.wrappedValue.label
            
            // Check for duplicate label
            if let collectionName = viewModel.selectedCollectionName {
                if !viewModel.isLabelUnique(trimmed, excludingItemId: item.wrappedValue.id, in: collectionName, document: document) {
                    errorMessage = "An item with this label already exists. Please choose a unique label."
                    editingLabel = oldLabel
                    return
                }
            }
            
            // Rename folder if assets folder exists
            if let collectionName = viewModel.selectedCollectionName,
               let assets = ensureAssetsFolder() {
                let colFolder = CollectionFS.collectionsRoot(in: assets)
                    .appendingPathComponent(CollectionFS.safeName(collectionName), isDirectory: true)
                
                do {
                    let newFolder = try CollectionFS.renameItemFolder(
                        collectionFolder: colFolder,
                        oldLabel: oldLabel,
                        newLabel: trimmed
                    )
                    
                    // Rebase file path if it exists
                    if var fp = item.wrappedValue.filePath, !fp.path.isEmpty {
                        let filename = URL(fileURLWithPath: fp.path).lastPathComponent
                        let newRelativePath = newFolder.relativePath(from: assets) ?? "Collections/\(CollectionFS.safeName(collectionName))/\(CollectionFS.safeName(trimmed))"
                        fp.path = "\(newRelativePath)/\(filename)"
                        item.wrappedValue.filePath = fp
                    }
                    
                    // Rebase thumbnail path if it exists
                    if !item.wrappedValue.thumbnail.path.isEmpty {
                        let filename = URL(fileURLWithPath: item.wrappedValue.thumbnail.path).lastPathComponent
                        let newRelativePath = newFolder.relativePath(from: assets) ?? "Collections/\(CollectionFS.safeName(collectionName))/\(CollectionFS.safeName(trimmed))"
                        item.wrappedValue.thumbnail.path = "\(newRelativePath)/\(filename)"
                    }
                    
                    errorMessage = nil
                } catch {
                    errorMessage = "Failed to rename folder: \(error.localizedDescription)"
                    // Revert the label change in UI
                    editingLabel = oldLabel
                    return
                }
            }
            
            // Update the label
            item.wrappedValue.label = trimmed
        }
    }
    
    private func commitSummary(to item: Binding<JSONCollectionItem>) {
        let trimmed = editingSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSummary = trimmed.isEmpty ? nil : trimmed
        if newSummary != item.wrappedValue.summary {
            item.wrappedValue.summary = newSummary
        }
    }
    
    private var filteredProjects: [ProjectDoc] {
        let base: [ProjectDoc] = showPrivateProjects ? allProjects : allProjects.filter { $0.isPublic }
        let currentPath = document.filePath?.path ?? ""
        if currentPath.isEmpty { return base }
        return base.filter { $0.filePath != currentPath }
    }
    
    private func projectIdString(_ p: ProjectDoc) -> String {
        return p.filePath
    }
    
    private func ensureAssetsFolder() -> URL? {
        if let loc = document.assetsFolder, let resolved = loc.resolvedURL() {
            return resolved
        }
        return AssetFolderManager.shared.ensureAssetsFolder(for: $document)
    }
    
    // MARK: - Actions
    
    private func pickFileForOriginal(item: Binding<JSONCollectionItem>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            var fp = item.wrappedValue.filePath ?? AssetPath()
            fp.pathToOriginal = url.path
            fp.pathToEdited = ""
            item.wrappedValue.filePath = fp
            item.wrappedValue.type = .file
        }
    }
    
    private func pickImageForThumbnail(item: Binding<JSONCollectionItem>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            copyThumbnailIntoAssets(from: url, item: item)
        }
    }
    
    private func copyOriginalIntoAssets(item: Binding<JSONCollectionItem>) {
        guard ensureAssetsFolder() != nil else { return }
        guard !item.wrappedValue.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let fp = item.wrappedValue.filePath, let original = fp.pathToOriginal, !original.isEmpty else { return }
        
        let src = URL(fileURLWithPath: original)
        viewModel.copyFileToAssets(from: src, document: $document)
        errorMessage = nil
    }
    
    private func copyThumbnailIntoAssets(from src: URL, item: Binding<JSONCollectionItem>) {
        guard let collectionName = viewModel.selectedCollectionName else { return }
        guard let assets = ensureAssetsFolder() else { return }
        guard !item.wrappedValue.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        do {
            let colFolder = try CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: collectionName)
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: item.wrappedValue.label)
            let ext = src.pathExtension.isEmpty ? "png" : src.pathExtension
            let dest = itemFolder.appendingPathComponent("thumbnail").appendingPathExtension(ext)
            
            let fm = FileManager.default
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: src.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                errorMessage = "Cannot copy a folder as thumbnail. Please select an image file."
                return
            }
            
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            
            try fm.copyItem(at: src, to: dest)
            
            let relativePath = dest.relativePath(from: assets) ?? dest.lastPathComponent
            item.wrappedValue.thumbnail = AssetPath(id: UUID(), path: relativePath)
            
            thumbnailRefreshKey = UUID()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func removeItemFile(item: Binding<JSONCollectionItem>) {
        if let edited = item.wrappedValue.filePath?.pathToEdited, !edited.isEmpty {
            let fm = FileManager.default
            if fm.fileExists(atPath: edited) { try? fm.removeItem(atPath: edited) }
        }
        item.wrappedValue.filePath = nil
    }
    
    private func removeThumbnail(item: Binding<JSONCollectionItem>) {
        if !item.wrappedValue.thumbnail.path.isEmpty,
           let assets = document.assetsFolder?.resolvedURL() {
            let fileURL = assets.appendingPathComponent(item.wrappedValue.thumbnail.path)
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: fileURL)
            }
        }
        item.wrappedValue.thumbnail = AssetPath()
        thumbnailRefreshKey = UUID()
    }
}

// MARK: - Helper Views

private struct ThumbnailContentView: View {
    @Binding var item: JSONCollectionItem
    let document: FolioDocument
    @Binding var isDropTargeted: Bool
    let onCopyThumbnail: (URL) -> Void
    let onPickImage: () -> Void
    let onRemoveThumbnail: () -> Void
    
    var body: some View {
        if let url = urlForAssetPath(item.thumbnail) {
            let readableURL = getReadableURL(url)
            
            if let readable = readableURL {
                if let img = NSImage(contentsOf: readable) {
                    thumbnailPreview(image: img, url: readable)
                } else {
                    Text("Failed to load image")
                        .foregroundStyle(.red)
                }
            } else {
                PermissionRequiredRow(title: "Thumbnail", url: url) { granted in
                    onCopyThumbnail(granted)
                }
            }
        } else {
            DropTargetView(
                isTargeted: $isDropTargeted,
                title: "Drop image or click to browse",
                acceptImagesOnly: true
            ) { url in
                onCopyThumbnail(url)
            }
            .onTapGesture { onPickImage() }
        }
    }
    
    private func urlForAssetPath(_ asset: AssetPath) -> URL? {
        if !asset.path.isEmpty, let assetsURL = document.assetsFolder?.resolvedURL() {
            return assetsURL.appendingPathComponent(asset.path)
        }
        if let edited = asset.pathToEdited, !edited.isEmpty { return URL(fileURLWithPath: edited) }
        if let original = asset.pathToOriginal, !original.isEmpty { return URL(fileURLWithPath: original) }
        return nil
    }
    
    private func getReadableURL(_ url: URL) -> URL? {
        if let resolved = PermissionHelper.resolvedURL(forOriginalPath: url.path, from: document.documentWrapper) {
            return resolved
        }
        return PermissionHelper.isReadable(url) ? url : nil
    }
    
    private func thumbnailPreview(image: NSImage, url: URL) -> some View {
        VStack(spacing: 8) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 160)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.2)))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                    Text(url.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(role: .destructive) {
                    onRemoveThumbnail()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct FileSourceContentView: View {
    @Binding var item: JSONCollectionItem
    let document: FolioDocument
    @Binding var isDropTargeted: Bool
    let onPickFile: () -> Void
    let onRemoveFile: () -> Void
    
    var body: some View {
        if let fp = item.filePath, let url = urlForAssetPath(fp) {
            let effectiveURL = getEffectiveURL(url)
            
            if let effective = effectiveURL {
                let preloaded = NSImage(contentsOf: effective)
                FilePreviewRow(url: effective, title: "File", preloadedImage: preloaded) {
                    onRemoveFile()
                }
            } else {
                PermissionRequiredRow(title: "File", url: url) { granted in
                    var fp = item.filePath ?? AssetPath()
                    if fp.pathToEdited?.isEmpty ?? true {
                        fp.pathToOriginal = granted.path
                    } else {
                        fp.pathToEdited = granted.path
                    }
                    item.filePath = fp
                    item.type = .file
                }
            }
        } else {
            DropTargetView(
                isTargeted: $isDropTargeted,
                title: "Drag file or click to browse"
            ) { url in
                var fp = item.filePath ?? AssetPath()
                fp.pathToOriginal = url.path
                item.filePath = fp
                item.type = .file
            }
            .onTapGesture { onPickFile() }
        }
    }
    
    private func getEffectiveURL(_ url: URL) -> URL? {
        if PermissionHelper.isReadable(url) {
            return url
        }
        if let resolved = PermissionHelper.resolvedURL(forOriginalPath: url.path, from: document.documentWrapper) {
            return resolved
        }
        return nil
    }
    
    private func urlForAssetPath(_ asset: AssetPath) -> URL? {
        if !asset.path.isEmpty, let assetsURL = document.assetsFolder?.resolvedURL() {
            return assetsURL.appendingPathComponent(asset.path)
        }
        if let edited = asset.pathToEdited, !edited.isEmpty { return URL(fileURLWithPath: edited) }
        if let original = asset.pathToOriginal, !original.isEmpty { return URL(fileURLWithPath: original) }
        return nil
    }
}


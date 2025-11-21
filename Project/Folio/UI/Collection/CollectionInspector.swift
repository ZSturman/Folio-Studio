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
    @State private var editingLabel: String = ""
    @State private var editingSummary: String = ""
    @State private var editingUrl: String = ""
    @State private var thumbnailRefreshKey: UUID = UUID()
    @FocusState private var labelFieldFocused: Bool
    @FocusState private var summaryFieldFocused: Bool
    
    // Debounce timers for performance
    @State private var labelDebounceTimer: Timer?
    @State private var summaryDebounceTimer: Timer?
    
    var body: some View {
        ScrollView {
            if let item = viewModel.selectedItem {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    
                    thumbnailSection(item: item)
                    
                    labelSection(item: item)
                    
                    summarySection(item: item)
                    
                    fileSourceSection(item: item)
                    
                    resourceSection(item: item)
                    
                    deleteSection
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                .id(item.id)
                .onAppear {
                    syncLocalState(from: item)
                }
                .onChange(of: item.id) { oldId, newId in
                    // Commit any pending changes before switching items
                    if oldId != newId {
                        print("[CollectionInspector] 🔄 Item changed from \(oldId) to \(newId), committing pending changes")
                        commitPendingChanges()
                    }
                    if let currentItem = viewModel.selectedItem {
                        syncLocalState(from: currentItem)
                    }
                }
                .onDisappear {
                    // Commit any pending changes when inspector closes
                    print("[CollectionInspector] 👋 Inspector disappearing, committing pending changes")
                    commitPendingChanges()
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
    
    private func thumbnailSection(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thumbnail")
                .font(.subheadline)
                .bold()
            
            ThumbnailContentView(
                item: item,
                document: document,
                isDropTargeted: $isDropTargetedThumb,
                onCopyThumbnail: copyThumbnailIntoAssets,
                onPickImage: pickImageForThumbnail,
                onRemoveThumbnail: removeThumbnail
            )
            .id(thumbnailRefreshKey)
        }
        .onAppear {
            print("[CollectionInspector] 🖼️ Thumbnail section appeared for item: \(item.id)")
            print("  - Thumbnail path: \(item.thumbnail.path)")
            print("  - Thumbnail original: \(item.thumbnail.pathToOriginal ?? "nil")")
            print("  - Thumbnail edited: \(item.thumbnail.pathToEdited ?? "nil")")
        }
    }
    
    private func labelSection(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Label")
                .font(.subheadline)
                .bold()
            
            TextField("Item label", text: $editingLabel)
                .textFieldStyle(.roundedBorder)
                .focused($labelFieldFocused)
                .onSubmit {
                    // Cancel debounce and commit immediately on submit
                    labelDebounceTimer?.invalidate()
                    commitLabel()
                }
                .onChange(of: editingLabel) { _, _ in
                    // Debounce label changes
                    labelDebounceTimer?.invalidate()
                    labelDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
                        commitLabel()
                    }
                }
                .onChange(of: labelFieldFocused) { _, isFocused in
                    if !isFocused {
                        // Cancel debounce and commit immediately when losing focus
                        labelDebounceTimer?.invalidate()
                        commitLabel()
                    }
                }
        }
    }
    
    private func summarySection(item: JSONCollectionItem) -> some View {
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
                        // Debounce summary changes
                        summaryDebounceTimer?.invalidate()
                        summaryDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            commitSummary()
                        }
                    }
                    .onChange(of: summaryFieldFocused) { _, isFocused in
                        if !isFocused {
                            // Cancel debounce and commit immediately when losing focus
                            summaryDebounceTimer?.invalidate()
                            commitSummary()
                        }
                    }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )
        }
    }
    
    private func fileSourceSection(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Source")
                    .font(.subheadline)
                    .bold()
                Spacer()
                Picker("Source", selection: Binding(
                    get: {
                        // Always read from the current item
                        viewModel.selectedItem?.type ?? item.type
                    },
                    set: { newValue in
                        print("[CollectionInspector] 🔄 Source type picker changed to: \(newValue)")
                        guard let currentItem = viewModel.selectedItem else {
                            print("  ❌ No selected item")
                            return
                        }
                        
                        if newValue != currentItem.type {
                            print("  ✅ Updating item type from \(currentItem.type) to \(newValue)")
                            // Commit outside of view update to avoid conflicts
                            Task { @MainActor in
                                viewModel.updateItem { item in
                                    item.type = newValue
                                    switch newValue {
                                    case .file:
                                        item.url = nil
                                    case .urlLink:
                                        item.filePath = nil
                                    case .folio:
                                        item.filePath = nil
                                        // Initialize with first project if available
                                        if item.url == nil, let firstProject = self.filteredProjects.first {
                                            item.url = self.projectIdString(firstProject)
                                        }
                                    }
                                }
                            }
                        }
                    }
                )) {
                    Text("File").tag(CollectionItemType.file)
                    Text("URL").tag(CollectionItemType.urlLink)
                    Text("Folio").tag(CollectionItemType.folio)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .id("source-\(item.id)-\(item.type.rawValue)") // Force refresh when item or type changes
            }
            
            Group {
                switch item.type {
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
    
    private func fileTypeContent(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FileSourceContentView(
                item: item,
                document: document,
                isDropTargeted: $isDropTargetedFile,
                viewModel: viewModel,
                onPickFile: pickFileForOriginal,
                onRemoveFile: removeItemFile
            )
            
            if let fp = item.filePath, !(fp.pathToOriginal?.isEmpty ?? true) {
                LabeledContent("Original") {
                    Text(fp.pathToOriginal ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            if let fp = item.filePath, !(fp.pathToEdited?.isEmpty ?? true) {
                LabeledContent("Edited") {
                    Text(fp.pathToEdited ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            
            Button {
                copyOriginalIntoAssets()
            } label: {
                Label("Copy to assets", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.bordered)
            .disabled(item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (item.filePath?.pathToOriginal ?? "").isEmpty)
        }
    }
    
    private func urlTypeContent(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("https://example.com", text: Binding(
                get: {
                    // Always get latest from viewModel
                    viewModel.selectedItem?.url ?? item.url ?? ""
                },
                set: { newValue in
                    editingUrl = newValue
                }
            ))
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    commitUrl()
                }
                .onChange(of: editingUrl) { _, _ in
                    // Could add debounce here if needed, but URL is typically pasted/typed once
                    // For now, commit on submit or focus loss only
                }
            
            if let urlString = item.url, !urlString.isEmpty {
                Text(urlString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }
    
    private func folioTypeContent(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Project", selection: Binding(
                get: {
                    // Always get the latest from viewModel to ensure synchronization
                    let currentUrl = viewModel.selectedItem?.url ?? item.url ?? ""
                    return filteredProjects
                        .first(where: { projectIdString($0) == currentUrl })
                        .map { projectIdString($0) } ?? ""
                },
                set: { newValue in
                    print("[CollectionInspector] 🔗 Project selection changed to: \(newValue)")
                    // Use Task to avoid publishing changes during view updates
                    Task { @MainActor in
                        viewModel.updateItem { item in
                            item.url = newValue.isEmpty ? nil : newValue
                        }
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
            
            if let selectedId = item.url,
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
    
    private func resourceSection(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Resource")
                .font(.subheadline)
                .bold()
            
            ResourcePickerView(
                resource: Binding(
                    get: {
                        // Always get the latest from viewModel to ensure synchronization
                        viewModel.selectedItem?.resource ?? item.resource
                    },
                    set: { newValue in
                        print("[CollectionInspector] 📚 Resource changed to category: \(newValue.category), type: \(newValue.type)")
                        // Use Task to avoid publishing changes during view updates
                        Task { @MainActor in
                            viewModel.updateItem { item in
                                print("  📚 Updating item resource from \(item.resource.category)/\(item.resource.type) to \(newValue.category)/\(newValue.type)")
                                item.resource = newValue
                            }
                        }
                    }
                ),
                document: $document
            )
            .id("resource-\(item.id)-\(item.resource.category)-\(item.resource.type)") // Force refresh when item or resource changes
        }
    }
    
    private var deleteSection: some View {
        Button(role: .destructive) {
            viewModel.deleteItem()
        } label: {
            Label("Delete Item", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
    
    // MARK: - Helpers
    
    private func syncLocalState(from item: JSONCollectionItem) {
        print("[CollectionInspector] 🔄 Syncing local state for item: \(item.id)")
        print("  - Label: \(item.label)")
        print("  - Summary: \(item.summary ?? "nil")")
        print("  - URL: \(item.url ?? "nil")")
        print("  - Type: \(item.type)")
        print("  - Resource: \(item.resource.category)/\(item.resource.type)")
        print("  - Thumbnail path: \(item.thumbnail.path)")
        
        // Cancel any pending debounce timers
        labelDebounceTimer?.invalidate()
        summaryDebounceTimer?.invalidate()
        
        // Sync all editing state
        editingLabel = item.label
        editingSummary = item.summary ?? ""
        editingUrl = item.url ?? ""
    }
    
    private func commitPendingChanges() {
        // Cancel and trigger any pending debounce timers
        if let timer = labelDebounceTimer, timer.isValid {
            timer.invalidate()
            commitLabel()
        }
        if let timer = summaryDebounceTimer, timer.isValid {
            timer.invalidate()
            commitSummary()
        }
    }
    
    private func commitLabel() {
        guard let item = viewModel.selectedItem else {
            print("[CollectionInspector] ⚠️ commitLabel: No selected item")
            return
        }
        let trimmed = editingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[CollectionInspector] 📝 Committing label: '\(trimmed)' (was: '\(item.label)')")
        if !trimmed.isEmpty && trimmed != item.label {
            print("  ✅ Label changed, updating...")
            viewModel.updateItemLabel(to: trimmed)
        } else if trimmed.isEmpty {
            print("  ⚠️ Label empty, restoring original")
            // Restore original if user cleared it
            editingLabel = item.label
        } else {
            print("  ℹ️ Label unchanged")
        }
    }
    
    private func commitSummary() {
        guard let item = viewModel.selectedItem else {
            print("[CollectionInspector] ⚠️ commitSummary: No selected item")
            return
        }
        let trimmed = editingSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSummary = trimmed.isEmpty ? nil : trimmed
        print("[CollectionInspector] 📝 Committing summary: '\(newSummary ?? "nil")' (was: '\(item.summary ?? "nil")')")
        if newSummary != item.summary {
            print("  ✅ Summary changed, updating...")
            viewModel.updateItem { item in
                item.summary = newSummary
            }
            // Verify update
            if let updatedItem = viewModel.selectedItem {
                print("  ✅ Verified summary is now: '\(updatedItem.summary ?? "nil")'")
            }
        } else {
            print("  ℹ️ Summary unchanged")
        }
    }
    
    private func commitUrl() {
        guard let item = viewModel.selectedItem else { return }
        let trimmed = editingUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let newUrl = trimmed.isEmpty ? nil : trimmed
        if newUrl != item.url {
            viewModel.updateItem { item in
                item.url = newUrl
                if !trimmed.isEmpty {
                    item.type = .urlLink
                    item.filePath = nil
                }
            }
        }
    }
    
    private var filteredProjects: [ProjectDoc] {
        if showPrivateProjects { return allProjects }
        return allProjects.filter { $0.isPublic }
    }
    
    private func projectIdString(_ p: ProjectDoc) -> String {
        // Use the persistentModelID's hashValue as a stable identifier
        // This works better than Mirror reflection with SwiftData models
        return p.persistentModelID.hashValue.description
    }
    
    private func previewURL(for original: String, edited: String) -> URL? {
        if !edited.isEmpty { return URL(fileURLWithPath: edited) }
        if !original.isEmpty { return URL(fileURLWithPath: original) }
        return nil
    }
    
    private func ensureAssetsFolder() -> URL? {
        if let loc = document.assetsFolder, let resolved = loc.resolvedURL() {
            return resolved
        }
        return AssetFolderManager.shared.ensureAssetsFolder(for: Binding(
            get: { document },
            set: { document = $0 }
        ))
    }
    
    // MARK: - Actions
    
    private func pickFileForOriginal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.updateItem { item in
                var fp = item.filePath ?? AssetPath()
                fp.pathToOriginal = url.path
                fp.pathToEdited = ""
                item.filePath = fp
                item.type = .file
                item.url = nil
            }
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
        guard let item = viewModel.selectedItem else { return }
        guard ensureAssetsFolder() != nil else { return }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let fp = item.filePath, let original = fp.pathToOriginal, !original.isEmpty else { return }
        
        let src = URL(fileURLWithPath: original)
        viewModel.copyFileToAssets(from: src)
        errorMessage = nil
    }
    
    private func copyThumbnailIntoAssets(from src: URL) {
        print("[CollectionInspector] 📎 Copying thumbnail from: \(src.path)")
        guard let item = viewModel.selectedItem,
              let collectionName = viewModel.selectedCollectionName else {
            print("  ❌ No selected item or collection")
            return
        }
        guard let assets = ensureAssetsFolder() else {
            print("  ❌ Could not ensure assets folder")
            return
        }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("  ❌ Item label is empty")
            return
        }
        
        do {
            let colFolder = try CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: collectionName)
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: item.label)
            let ext = src.pathExtension.isEmpty ? "png" : src.pathExtension
            let dest = itemFolder.appendingPathComponent("thumbnail").appendingPathExtension(ext)
            print("  📋 Destination: \(dest.path)")
            
            let fm = FileManager.default
            
            // CRITICAL FIX: Check if source is a file, not a directory
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: src.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                print("  ❌ Source is a directory, not a file: \(src.path)")
                errorMessage = "Cannot copy a folder as thumbnail. Please select an image file."
                return
            }
            
            // Remove existing thumbnail if present
            if fm.fileExists(atPath: dest.path) {
                print("  🗑️ Removing existing thumbnail")
                try fm.removeItem(at: dest)
            }
            
            // Copy the file (not folder)
            try fm.copyItem(at: src, to: dest)
            print("  ✅ Thumbnail copied successfully")
            
            // Calculate relative path from assets folder
            let relativePath = dest.relativePath(from: assets) ?? dest.lastPathComponent
            print("  📂 Relative path: \(relativePath)")
            
            viewModel.updateItem { item in
                item.thumbnail = AssetPath(id: UUID(), path: relativePath)
                print("  💾 Thumbnail AssetPath set with path: \(item.thumbnail.path)")
            }
            
            // Force thumbnail refresh
            thumbnailRefreshKey = UUID()
            print("  🔄 Thumbnail refresh triggered")
            
            errorMessage = nil
        } catch {
            print("  ❌ Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func removeItemFile() {
        guard let item = viewModel.selectedItem else { return }
        
        if let edited = item.filePath?.pathToEdited, !edited.isEmpty {
            let fm = FileManager.default
            if fm.fileExists(atPath: edited) { try? fm.removeItem(atPath: edited) }
        }
        
        viewModel.updateItem { item in
            item.filePath = nil
        }
    }
    
    private func removeThumbnail() {
        print("[CollectionInspector] 🗑️ Removing thumbnail")
        guard let item = viewModel.selectedItem else {
            print("  ❌ No selected item")
            return
        }
        
        // Delete the file if it exists
        if !item.thumbnail.path.isEmpty,
           let assets = document.assetsFolder?.resolvedURL() {
            let fileURL = assets.appendingPathComponent(item.thumbnail.path)
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                print("  🗑️ Deleting file: \(fileURL.path)")
                try? fm.removeItem(at: fileURL)
            }
        }
        
        viewModel.updateItem { item in
            item.thumbnail = AssetPath()  // Reset to empty
            print("  💾 Thumbnail reset to empty AssetPath")
        }
        
        // Force thumbnail refresh
        thumbnailRefreshKey = UUID()
        print("  ✅ Thumbnail removed and refresh triggered")
    }
}

// MARK: - Helper Views

private struct ThumbnailContentView: View {
    let item: JSONCollectionItem
    let document: FolioDocument
    @Binding var isDropTargeted: Bool
    let onCopyThumbnail: (URL) -> Void
    let onPickImage: () -> Void
    let onRemoveThumbnail: () -> Void
    
    var body: some View {
        let _ = print("[ThumbnailContentView] 🖼️ Rendering for item: \(item.id)")
        let _ = print("  - Thumbnail path: \(item.thumbnail.path)")
        let _ = print("  - Thumbnail original: \(item.thumbnail.pathToOriginal ?? "nil")")
        let _ = print("  - Thumbnail edited: \(item.thumbnail.pathToEdited ?? "nil")")
        
        if let url = urlForAssetPath(item.thumbnail) {
            let _ = print("  - URL resolved: \(url.path)")
            let readableURL = getReadableURL(url)
            
            if let readable = readableURL {
                let _ = print("  - URL is readable: \(readable.path)")
                if let img = NSImage(contentsOf: readable) {
                    let _ = print("  ✅ Image loaded successfully")
                    thumbnailPreview(image: img, url: readable)
                } else {
                    let _ = print("  ❌ Failed to load NSImage from URL")
                    Text("Failed to load image")
                        .foregroundStyle(.red)
                }
            } else {
                let _ = print("  ⚠️ URL not readable, showing permission request")
                PermissionRequiredRow(title: "Thumbnail", url: url) { granted in
                    onCopyThumbnail(granted)
                }
            }
        } else {
            let _ = print("  📭 No thumbnail URL, showing drop target")
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
    
    private func previewURL(for original: String, edited: String) -> URL? {
        if !edited.isEmpty { return URL(fileURLWithPath: edited) }
        if !original.isEmpty { return URL(fileURLWithPath: original) }
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
    let item: JSONCollectionItem
    let document: FolioDocument
    @Binding var isDropTargeted: Bool
    @ObservedObject var viewModel: CollectionViewModel
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
                    viewModel.updateItem { item in
                        if item.filePath == nil {
                            item.filePath = AssetPath(pathToOriginal: granted.path, pathToEdited: "")
                        } else {
                            if item.filePath?.pathToEdited?.isEmpty ?? true {
                                item.filePath?.pathToOriginal = granted.path
                            } else {
                                item.filePath?.pathToEdited = granted.path
                            }
                        }
                        item.type = .file
                        item.url = nil
                    }
                }
            }
        } else {
            DropTargetView(
                isTargeted: $isDropTargeted,
                title: "Drag file or click to browse"
            ) { url in
                viewModel.updateItem { item in
                    var fp = item.filePath ?? AssetPath()
                    fp.pathToOriginal = url.path
                    item.filePath = fp
                    item.type = .file
                    item.url = nil
                }
            }
            .onTapGesture { onPickFile() }
        }
    }
    
    private func previewURL(for original: String, edited: String) -> URL? {
        if !edited.isEmpty { return URL(fileURLWithPath: edited) }
        if !original.isEmpty { return URL(fileURLWithPath: original) }
        return nil
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


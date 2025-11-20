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
    @State private var localSummary: String = ""
    @State private var localLabel: String = ""
    @State private var localUrl: String = ""
    
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
                .onAppear {
                    // Initialize local state from item
                    localSummary = item.summary ?? ""
                    localLabel = item.label
                    localUrl = item.url ?? ""
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
            
            if let url = previewURL(for: item.thumbnail.pathToOriginal, edited: item.thumbnail.pathToEdited) {
                let readableURL = PermissionHelper.resolvedURL(forOriginalPath: url.path)
                    ?? (PermissionHelper.isReadable(url) ? url : nil)
                if let u = readableURL, let img = NSImage(contentsOf: u) {
                    thumbnailPreview(image: img, url: u)
                } else {
                    PermissionRequiredRow(title: "Thumbnail", url: url) { granted in
                        copyThumbnailIntoAssets(from: granted)
                    }
                }
            } else {
                DropTargetView(
                    isTargeted: $isDropTargetedThumb,
                    title: "Drop image or click to browse",
                    acceptImagesOnly: true
                ) { url in
                    copyThumbnailIntoAssets(from: url)
                }
                .onTapGesture { pickImageForThumbnail() }
            }
        }
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
                    removeThumbnail()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
    }
    
    private func labelSection(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Label")
                .font(.subheadline)
                .bold()
            
            TextField("Item label", text: $localLabel)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if localLabel != item.label {
                        viewModel.updateItemLabel(to: localLabel)
                    }
                }
                .onChange(of: item.label) { _, newValue in
                    localLabel = newValue
                }
        }
    }
    
    private func summarySection(item: JSONCollectionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary")
                .font(.subheadline)
                .bold()
            
            ZStack(alignment: .topLeading) {
                if localSummary.isEmpty {
                    Text("Write a short overview...")
                        .foregroundStyle(.secondary)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
                }
                
                TextEditor(text: $localSummary)
                    .frame(minHeight: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .onChange(of: localSummary) { _, newValue in
                        viewModel.updateItem { item in
                            item.summary = newValue.isEmpty ? nil : newValue
                        }
                    }
                    .onChange(of: item.summary) { _, newValue in
                        localSummary = newValue ?? ""
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
                    get: { item.type },
                    set: { newType in
                        viewModel.updateItem { item in
                            item.type = newType
                            switch newType {
                            case .file:
                                item.url = nil
                            case .urlLink:
                                item.filePath = nil
                            case .folio:
                                item.filePath = nil
                                item.url = nil
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
            if let url = previewURL(for: item.filePath?.pathToOriginal ?? "", edited: item.filePath?.pathToEdited ?? "") {
                if PermissionHelper.isReadable(url) || PermissionHelper.resolvedURL(forOriginalPath: url.path) != nil {
                    let effectiveURL = PermissionHelper.resolvedURL(forOriginalPath: url.path) ?? url
                    let preloaded = NSImage(contentsOf: effectiveURL)
                    FilePreviewRow(url: effectiveURL, title: "File", preloadedImage: preloaded) {
                        removeItemFile()
                    }
                } else {
                    PermissionRequiredRow(title: "File", url: url) { granted in
                        viewModel.updateItem { item in
                            if item.filePath == nil {
                                item.filePath = AssetPath(pathToOriginal: granted.path)
                            } else {
                                if item.filePath?.pathToEdited.isEmpty ?? true {
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
                    isTargeted: $isDropTargetedFile,
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
                .onTapGesture { pickFileForOriginal() }
            }
            
            if let fp = item.filePath, !fp.pathToOriginal.isEmpty {
                LabeledContent("Original") {
                    Text(fp.pathToOriginal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            if let fp = item.filePath, !fp.pathToEdited.isEmpty {
                LabeledContent("Edited") {
                    Text(fp.pathToEdited)
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
            TextField("https://example.com", text: $localUrl)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let trimmed = localUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.updateItem { item in
                        item.url = trimmed.isEmpty ? nil : trimmed
                        if !trimmed.isEmpty {
                            item.type = .urlLink
                            item.filePath = nil
                        }
                    }
                }
                .onChange(of: item.url) { _, newValue in
                    localUrl = newValue ?? ""
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
                    filteredProjects
                        .first(where: { projectIdString($0) == (item.url ?? "") })
                        .map { projectIdString($0) } ?? ""
                },
                set: { newValue in
                    viewModel.updateItem { item in
                        item.url = newValue.isEmpty ? nil : newValue
                    }
                }
            )) {
                if filteredProjects.isEmpty {
                    Text("None").tag("")
                } else {
                    ForEach(filteredProjects, id: \.self) { p in
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
                    get: { item.resource },
                    set: { newValue in
                        viewModel.updateItem { item in
                            item.resource = newValue
                        }
                    }
                ),
                currentDocumentURL: nil
            )
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
        guard let assets = ensureAssetsFolder() else { return }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let fp = item.filePath, !fp.pathToOriginal.isEmpty else { return }
        
        do {
            let src = URL(fileURLWithPath: fp.pathToOriginal)
            viewModel.copyFileToAssets(from: src)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func copyThumbnailIntoAssets(from src: URL) {
        guard let item = viewModel.selectedItem,
              let collectionName = viewModel.selectedCollectionName else { return }
        guard let assets = ensureAssetsFolder() else { return }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        do {
            let colFolder = try CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: collectionName)
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: item.label)
            let ext = src.pathExtension.isEmpty ? "png" : src.pathExtension
            let dest = itemFolder.appendingPathComponent("thumbnail").appendingPathExtension(ext)
            let fm = FileManager.default
            if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
            try fm.copyItem(at: src, to: dest)
            
            viewModel.updateItem { item in
                item.thumbnail.pathToOriginal = src.path
                item.thumbnail.pathToEdited = dest.path
            }
            errorMessage = nil
        } catch {
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
        guard let item = viewModel.selectedItem else { return }
        
        if !item.thumbnail.pathToEdited.isEmpty {
            let fm = FileManager.default
            let p = item.thumbnail.pathToEdited
            if fm.fileExists(atPath: p) { try? fm.removeItem(atPath: p) }
        }
        
        viewModel.updateItem { item in
            item.thumbnail.pathToOriginal = ""
            item.thumbnail.pathToEdited = ""
        }
    }
}

//
//  ResourcePickerView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Assumptions:
/// - `ProjectDoc` exists in SwiftData with at least: `id` (UUID or String), `name: String`, `isPublic: Bool`.
/// - Provide the current document's URL so sibling copy can be created at the same root.
///   If you do not have this yet, pass `nil` and the "Copy to local folder" button will disable.
struct ResourcePickerView: View {
    @Binding var resource: JSONResource
    @Binding var document: FolioDocument
    @Environment(\.modelContext) private var modelContext

    // All categories and types from SwiftData
    @Query(sort: [SortDescriptor(\ResourceItemCategory.name, order: .forward)])
    private var categories: [ResourceItemCategory]

    @Query(sort: [SortDescriptor(\ResourceItemType.name, order: .forward)])
    private var allTypes: [ResourceItemType]

    // Projects for localLink flow
    @Query(sort: [SortDescriptor(\ProjectDoc.title, order: .forward)])
    private var allProjects: [ProjectDoc]

    @State private var showPrivateProjects = false
    @State private var isDropTargeted = false

    // File import + drop state for localDownload
    @State private var showFileImporter = false
    @State private var pickedFileURL: URL? = nil
    @State private var copyError: String? = nil
    @State private var editableFileName: String = ""

    // Map the resource's string values to SwiftData objects
    private var selectedCategoryBinding: Binding<ResourceItemCategory?> {
        Binding<ResourceItemCategory?>(
            get: {
                // If we already match a category, use it
                if let exact = categories.first(where: { $0.name == resource.category }) {
                    return exact
                }
                // If no match and we have categories, return first but don't auto-snap
                return categories.first
            },
            set: { newValue in
                // Ignore nil; we never intentionally clear to an "empty" category
                guard let c = newValue else { return }

                resource.category = c.name
                // Snap type to first available for new category
                let first = allTypes
                    .filter { $0.category.id == c.id }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    .first
                resource.type = first?.name ?? ""

                // Reset URL UI when category changes
                pickedFileURL = nil
                copyError = nil
            }
        )
    }

    private var selectedTypeBinding: Binding<ResourceItemType?> {
        Binding<ResourceItemType?>(
            get: {
                guard let cat = selectedCategoryBinding.wrappedValue else { return nil }
                let options = allTypes
                    .filter { $0.category.id == cat.id }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                if let exact = options.first(where: { $0.name == resource.type }) {
                    return exact
                }
                // Return first option but don't auto-snap
                return options.first
            },
            set: { newValue in
                guard let t = newValue else { return }
                resource.type = t.name
            }
        )
    }

    private var typesForSelectedCategory: [ResourceItemType] {
        guard let c = selectedCategoryBinding.wrappedValue else { return [] }
        return allTypes
            .filter { $0.category.id == c.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // Category switches
    private var isLocalDownload: Bool { resource.category.caseInsensitiveCompare("download") == .orderedSame }
    private var isLocalLink: Bool { resource.category.caseInsensitiveCompare("folio") == .orderedSame }

    // Project list for localLink
    private var filteredProjects: [ProjectDoc] {
        if showPrivateProjects { return allProjects }
        return allProjects.filter { $0.isPublic }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Category + conditional "Type"/Project picker
            HStack(spacing: 8) {
                if categories.isEmpty {
                    Text("No categories available")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Category", selection: selectedCategoryBinding) {
                        ForEach(categories, id: \.id) { c in
                            Text(c.name.capitalized).tag(c as ResourceItemCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if isLocalLink {
                    // Project picker replaces Type
                    let projects = filteredProjects
                    if projects.isEmpty {
                        Text("No projects available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Project", selection: Binding(
                            get: {
                                // Map resource.url to a ProjectDoc if possible
                                if let match = projects.first(where: { $0.filePath == resource.url }) {
                                    return match.filePath
                                }
                                // Return empty if no match - don't auto-snap to avoid conflicts
                                return ""
                            },
                            set: { newValue in
                                // Also set type to selected project's title
                                guard let selected = projects.first(where: { $0.filePath == newValue }) else { return }
                                resource.url = selected.filePath
                                resource.type = selected.title
                            })
                        ) {
                            ForEach(projects, id: \.self) { p in
                                Text(p.title).tag(p.filePath)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } else {
                    // Normal Type UI for everything except localLink
                    let options = typesForSelectedCategory
                    if options.isEmpty {
                        Text("No types for this category")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Type", selection: selectedTypeBinding) {
                            ForEach(options, id: \.id) { t in
                                Text(t.name.capitalized).tag(t as ResourceItemType?)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isLocalDownload)
                    }
                }
            }

            // For localLink: show public toggle and warning when private enabled
            if isLocalLink {
                Toggle("Show private projects", isOn: $showPrivateProjects)
                    .toggleStyle(.switch)
                if showPrivateProjects {
                    Text("Warning: selecting a private project may cause downstream access issues.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            // Label always editable
            LabeledContent("Label") {
                TextField("e.g. Design Spec", text: $resource.label)
                    .textFieldStyle(.roundedBorder)
            }

            // URL input shown only for categories other than localDownload/localLink
            if !isLocalDownload && !isLocalLink {
                LabeledContent("URL") {
                    TextField("https://example.com", text: $resource.url)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                     
                }
            }

            // localDownload UI
            if isLocalDownload {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local File")
                        .font(.subheadline)
                        .bold()

                    // File preview or drop target
                    if let fileURL = pickedFileURL ?? existingFileURL() {
                        // Show small file preview
                        filePreviewCard(url: fileURL)
                    } else {
                        DropTarget(
                            isTargeted: $isDropTargeted,
                            pickedFileURL: $pickedFileURL,
                            onPick: handlePickedFile
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isDropTargeted ? .blue : .secondary, style: StrokeStyle(lineWidth: 1, dash: [6]))
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { showFileImporter = true }
                    }

                    // Type field (filename editor)
                    LabeledContent {
                        HStack(spacing: 4) {
                            TextField("No file added", text: $editableFileName)
                                .textFieldStyle(.roundedBorder)
                                .disabled(pickedFileURL == nil && existingFileURL() == nil)
                                .onChange(of: editableFileName) { _, newName in
                                    handleFileNameChange(newName)
                                }
                            
                            if let ext = fileExtension() {
                                Text(".\(ext)")
                                    .foregroundStyle(.secondary)
                                    .font(.body)
                            }
                        }
                    } label: {
                        Text("Type")
                    }

                    if let copyError {
                        Text(copyError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.item],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first { handlePickedFile(url) }
                    case .failure(let error):
                        copyError = error.localizedDescription
                    }
                }
            }
        }
        .onAppear {
            // Initialize defaults if empty
            if resource.category.isEmpty, let firstCat = categories.first {
                resource.category = firstCat.name
            }
            if resource.type.isEmpty, let cat = selectedCategoryBinding.wrappedValue {
                let firstType = allTypes
                    .filter { $0.category.id == cat.id }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    .first
                resource.type = firstType?.name ?? ""
            }
            // If localLink and resource.url is empty, seed with first visible project and set type to its title
            if isLocalLink, resource.url.isEmpty, let first = filteredProjects.first {
                resource.url = first.filePath
                resource.type = first.title
            }
            // If localDownload, initialize editableFileName from resource.type
            if isLocalDownload {
                editableFileName = resource.type
            }
        }
    }

    // MARK: - Helpers

    private func handlePickedFile(_ url: URL) {
        pickedFileURL = url
        copyError = nil
        
        // Automatically copy to AssetFolder/Resources
        copyToAssetFolderResources(sourceURL: url)
    }
    
    private func copyToAssetFolderResources(sourceURL: URL) {
        guard let assetsFolderURL = document.assetsFolder?.resolvedURL() else {
            copyError = "Assets folder not set"
            return
        }
        
        let resourcesFolder = assetsFolderURL.appendingPathComponent("Resources", isDirectory: true)
        let fm = FileManager.default
        
        // Create Resources folder if needed
        if !fm.fileExists(atPath: resourcesFolder.path) {
            do {
                try fm.createDirectory(at: resourcesFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                copyError = "Failed to create Resources folder: \(error.localizedDescription)"
                return
            }
        }
        
        // Copy file with collision handling
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var dest = resourcesFolder.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1
        
        while fm.fileExists(atPath: dest.path) {
            let candidateName = "\(baseName)_\(counter)" + (ext.isEmpty ? "" : ".\(ext)")
            dest = resourcesFolder.appendingPathComponent(candidateName)
            counter += 1
        }
        
        do {
            try fm.copyItem(at: sourceURL, to: dest)
            
            // Calculate relative path from AssetFolder
            let relativePath = dest.relativePath(from: assetsFolderURL) ?? "Resources/\(dest.lastPathComponent)"
            
            // Update resource with relative path
            resource.url = relativePath
            
            // Set type to filename without extension
            editableFileName = baseName
            resource.type = baseName
            
        } catch {
            copyError = "Failed to copy file: \(error.localizedDescription)"
        }
    }
    
    private func handleFileNameChange(_ newName: String) {
        guard let assetsFolderURL = document.assetsFolder?.resolvedURL(),
              !resource.url.isEmpty else { return }
        
        let currentFileURL = assetsFolderURL.appendingPathComponent(resource.url)
        guard FileManager.default.fileExists(atPath: currentFileURL.path) else { return }
        
        let ext = currentFileURL.pathExtension
        let newFileName = newName + (ext.isEmpty ? "" : ".\(ext)")
        let newFileURL = currentFileURL.deletingLastPathComponent().appendingPathComponent(newFileName)
        
        do {
            try FileManager.default.moveItem(at: currentFileURL, to: newFileURL)
            
            // Update relative path
            let relativePath = newFileURL.relativePath(from: assetsFolderURL) ?? "Resources/\(newFileName)"
            resource.url = relativePath
            resource.type = newName
            
        } catch {
            copyError = "Failed to rename file: \(error.localizedDescription)"
        }
    }
    
    private func existingFileURL() -> URL? {
        guard !resource.url.isEmpty,
              let assetsFolderURL = document.assetsFolder?.resolvedURL() else { return nil }
        
        let fileURL = assetsFolderURL.appendingPathComponent(resource.url)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    private func fileExtension() -> String? {
        if let url = pickedFileURL {
            let ext = url.pathExtension
            return ext.isEmpty ? nil : ext
        }
        if let url = existingFileURL() {
            let ext = url.pathExtension
            return ext.isEmpty ? nil : ext
        }
        return nil
    }
    
    @ViewBuilder
    private func filePreviewCard(url: URL) -> some View {
        HStack(spacing: 12) {
            // Icon preview
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let resizedIcon = icon.resized(to: CGSize(width: 48, height: 48))
            
            Image(nsImage: resizedIcon)
                .resizable()
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(1)
                
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                removeFile()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func removeFile() {
        guard let assetsFolderURL = document.assetsFolder?.resolvedURL(),
              !resource.url.isEmpty else { return }
        
        let fileURL = assetsFolderURL.appendingPathComponent(resource.url)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            resource.url = ""
            resource.type = ""
            editableFileName = ""
            pickedFileURL = nil
        } catch {
            copyError = "Failed to remove file: \(error.localizedDescription)"
        }
    }
}

// MARK: - DropTarget view

private struct DropTarget: View {
    @Binding var isTargeted: Bool
    @Binding var pickedFileURL: URL?
    var onPick: (URL) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down.on.square")
                .imageScale(.large)
            Text("Drag a file here or click to browse")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onDrop(of: [.fileURL, .image, .data], isTargeted: $isTargeted) { providers in
            // Prefer direct file URL
            if let item = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
                _ = item.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { onPick(url) } }
                }
                return true
            }
            // Fallback: try data/image and write to a temp file for a path
            if let item = providers.first {
                item.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, _ in
                    guard let data else { return }
                    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString)
                    do {
                        try data.write(to: tmp)
                        DispatchQueue.main.async { onPick(tmp) }
                    } catch { /* ignore */ }
                }
                return true
            }
            return false
        }
        .accessibilityAddTraits(.isButton)
    }
}




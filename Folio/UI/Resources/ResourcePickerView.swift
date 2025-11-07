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
    @Environment(\.modelContext) private var modelContext

    /// Optional. Used only when copying a dropped/selected file to a local sibling folder.
    var currentDocumentURL: URL?

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
    @State private var copySuggestionVisible = false
    @State private var copyError: String? = nil

    // Map the resource's string values to SwiftData objects
    private var selectedCategoryBinding: Binding<ResourceItemCategory?> {
        Binding<ResourceItemCategory?>(
            get: {
                categories.first(where: { $0.name == resource.category })
            },
            set: { newValue in
                if let c = newValue {
                    resource.category = c.name
                    // Snap type to first available for new category
                    let first = allTypes
                        .filter { $0.category.id == c.id }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        .first
                    resource.type = first?.name ?? ""
                } else {
                    resource.category = ""
                    resource.type = ""
                }
                // Reset URL UI when category changes
                pickedFileURL = nil
                copySuggestionVisible = false
                copyError = nil
            }
        )
    }

    private var selectedTypeBinding: Binding<ResourceItemType?> {
        Binding<ResourceItemType?>(
            get: {
                guard let cat = selectedCategoryBinding.wrappedValue else { return nil }
                let options = allTypes.filter { $0.category.id == cat.id }
                return options.first(where: { $0.name == resource.type })
            },
            set: { newValue in
                if let t = newValue { resource.type = t.name } else { resource.type = "" }
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
    private var isLocalDownload: Bool { resource.category.caseInsensitiveCompare("localDownload") == .orderedSame }
    private var isLocalLink: Bool { resource.category.caseInsensitiveCompare("localLink") == .orderedSame }

    // Project list for localLink
    private var filteredProjects: [ProjectDoc] {
        if showPrivateProjects { return allProjects }
        return allProjects.filter { $0.isPublic }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Category + conditional "Type"/Project picker
            HStack(spacing: 8) {
                Picker("Category", selection: selectedCategoryBinding) {
                    if categories.isEmpty {
                        Text("None").tag(nil as ResourceItemCategory?)
                    } else {
                        ForEach(categories, id: \.id) { c in
                            Text(c.name.capitalized).tag(c as ResourceItemCategory?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .disabled(categories.isEmpty)

                if isLocalLink {
                    // Project picker replaces Type
                    Picker("Project", selection: Binding(
                        get: {
                            // Map resource.url to a ProjectDoc if possible
                            filteredProjects.first(where: { projectIdString($0) == resource.url })
                                .map { projectIdString($0) } ?? ""
                        },
                        set: { newValue in
                            resource.url = newValue
                            // Also set type to selected project's title
                            if let selected = filteredProjects.first(where: { projectIdString($0) == newValue }) {
                                resource.type = selected.title
                            }
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
                } else {
                    // Normal Type picker for everything except localLink
                    Picker("Type", selection: selectedTypeBinding) {
                        let options = typesForSelectedCategory
                        if options.isEmpty {
                            Text("None").tag(nil as ResourceItemType?)
                        } else {
                            ForEach(options, id: \.id) { t in
                                Text(t.name.capitalized).tag(t as ResourceItemType?)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(typesForSelectedCategory.isEmpty || isLocalDownload)
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

                    if let file = pickedFileURL {
                        LabeledContent("Selected") {
                            Text(file.path)
                                .font(.footnote)
                                .textSelection(.enabled)
                        }
                    }

                    if copySuggestionVisible {
                        HStack(spacing: 8) {
                            Button {
                                do {
                                    try copyToSiblingFolderAndCaptureURL()
                                } catch {
                                    copyError = error.localizedDescription
                                }
                            } label: {
                                Label("Copy to local folder", systemImage: "doc.on.doc")
                            }
                            .disabled(currentDocumentURL == nil)

                            if currentDocumentURL == nil {
                                Text("Provide currentDocumentURL to enable copying.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let copyError {
                            Text(copyError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
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
                resource.url = projectIdString(first)
                resource.type = first.title
            }
        }
    }

    // MARK: - Helpers

    private func handlePickedFile(_ url: URL) {
        pickedFileURL = url
        resource.url = url.path // save chosen path immediately
        copySuggestionVisible = true
        copyError = nil
    }

    private func copyToSiblingFolderAndCaptureURL() throws {
        guard let src = pickedFileURL else { return }
        guard let docURL = currentDocumentURL else { return }

        let root = docURL.deletingLastPathComponent()
        let folder = root.appendingPathComponent("LocalResources", isDirectory: true)

        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path) {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }

        // Resolve final destination with collision handling
        let baseName = src.deletingPathExtension().lastPathComponent
        let ext = src.pathExtension
        var dest = folder.appendingPathComponent(src.lastPathComponent)
        var counter = 1
        while fm.fileExists(atPath: dest.path) {
            let candidateName = "\(baseName)_\(counter)" + (ext.isEmpty ? "" : ".\(ext)")
            dest = folder.appendingPathComponent(candidateName)
            counter += 1
        }

        // Use copy. If you want move, swap to moveItem.
        try fm.copyItem(at: src, to: dest)

        // Save copied path as the resource url
        resource.url = dest.path
        copySuggestionVisible = false
    }

    private func projectIdString(_ p: ProjectDoc) -> String {
        // Prefer an `id` property if present (UUID or String)
        let mirror = Mirror(reflecting: p)
        if let idChild = mirror.children.first(where: { $0.label == "id" }) {
            if let uuidValue = idChild.value as? UUID {
                return uuidValue.uuidString
            }
            if let strValue = idChild.value as? String {
                return strValue
            }
        }
        // Fallback: descriptive string (should rarely be used)
        return String(describing: p)
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
//
//// MARK: - Preview
//
//#Preview {
//    // Preview with an in-memory container. Seeds once.
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: ResourceItemCategory.self, ResourceItemType.self, ProjectDoc.self, configurations: config)
//    let context = ModelContext(container)
//
//    if try! context.fetch(FetchDescriptor<ResourceItemCategory>()).isEmpty {
//        try! seedResourceCatalog(in: context, addedVia: .system)
//    }
//
//    // Minimal seed for projects
//    if try! context.fetch(FetchDescriptor<ProjectDoc>()).isEmpty {
//        let pub = ProjectDoc(name: "Public Project", isPublic: true)
//        let priv = ProjectDoc(name: "Private Project", isPublic: false)
//        context.insert(pub)
//        context.insert(priv)
//        try! context.save()
//    }
//
//    let sample = JSONResource(label: "Design Doc",
//                              category: try! context.fetch(FetchDescriptor<ResourceItemCategory>()).first?.name ?? "",
//                              type: "",
//                              url: "https://example.com/spec")
//
//    ResourcePickerView(resource: .constant(sample), currentDocumentURL: URL(fileURLWithPath: "/Users/me/Documents/Folio/MyDoc.folio"))
//        .modelContainer(container)
//}




//
//  ContentView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import SwiftUI
import SwiftData

private enum JSONPanelViewMode: String, CaseIterable, Identifiable {
    case tree
    case raw
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tree: return "Tree"
        case .raw: return "Raw"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    
    @AppStorage("launcherAutoOpen") private var launcherAutoOpen = true
    @AppStorage("jsonPanelHeight") private var jsonPanelHeight: Double = 300
    @AppStorage("jsonPanelCollapsed") private var jsonPanelCollapsed: Bool = true
    
    @Binding var document: FolioDocument
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var inspectorState: InspectorState
    @StateObject private var sdc = SwiftDataCoordinator()
    @StateObject private var mediaImageEditorViewModel = ImageEditorViewModel()
    
    
    @State private var selection: SidebarTab? = .basicInfo

    @State private var basicInfoSubtab: BasicInfoSubtab? = .main
    @State private var contentSubtab:   ContentSubtab?   = .summary
    @State private var selectedLanguage: ProgrammingLanguage? = .swift
    @State private var selectedSnippetID: CodeSnippetID? = nil
    @State private var selectedResourceIndex: Int?
    @StateObject private var collectionViewModel: CollectionViewModel
    @State private var selectedImageLabel: ImageLabel = .thumbnail
    @State private var jsonString: String = ""
    @State private var jsonData: Data?
    @State private var jsonError: String?
    @State private var showAssetFolderPrompt: Bool = false
    @State private var jsonDebounceTask: Task<Void, Never>?
    @State private var jsonPanelViewMode: JSONPanelViewMode = .tree
    @State private var jsonPanelDragStartHeight: Double = 0
    
    var fileURL: URL?
    
    init(document: Binding<FolioDocument>, fileURL: URL?) {
        self._document = document
        self.fileURL = fileURL
        self._collectionViewModel = StateObject(wrappedValue: CollectionViewModel(
            undoManager: nil
        ))
    }

    var body: some View {
        VSplitView {
            // Top: Main content area
            NavigationSplitView {
                // 1st column: main sidebar
                SidebarTabsView(selection: $selection)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 200)

            } content: {
                secondarySidebar
                    .padding(.horizontal, 4)

            } detail: {
                // 3rd column: the actual editor / detail
                Group {
                    if let selection {
                        Group {
                            if selection == .media {
                                // Media tab needs full height for image canvas
                                detailView(for: selection)
                                    .environmentObject(sdc)
                            } else {
                                ScrollView {
                                    detailView(for: selection)
                                        .environmentObject(sdc)
                                }
                            }
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .automatic) {
                                Button(action: {
                                    inspectorState.isVisible.toggle()
                                    inspectorState.activeTab = selection
                                }) {
                                    Label("Inspector", systemImage: "sidebar.right")
                                }
                                .help("Toggle Inspector")
                            }
                        }
                    } else {
                        Text("Select a Tab")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                jsonPanel
                    .frame(height: jsonPanelCollapsed ? 30 : max(100, min(1200, jsonPanelHeight)))
            }
            .inspector(isPresented: $inspectorState.isVisible) {
                Group {
                    switch selection {
                    case .basicInfo:
                        BasicInfoInspector(document: $document)
                            .inspectorColumnWidth(min: 260, ideal: 300, max: 340)
                    
                    case .content:
                        ContentInspector(document: $document)
                            .inspectorColumnWidth(min: 260, ideal: 300, max: 340)
                    
                    case .media:
                        if let _ = document.images[selectedImageLabel] {
                            MediaInspectorView(
                                viewModel: mediaImageEditorViewModel,
                                selectedLabel: selectedImageLabel,
                                document: $document,
                                onImageImported: { image in
                                    handleImageImport(image)
                                },
                                onRevertToOriginal: {
                                    handleRevertToOriginal()
                                },
                                onClearImage: {
                                    handleClearImage()
                                }
                            )
                            .inspectorColumnWidth(min: 260, ideal: 300, max: 340)
                        } else {
                            Text("No image selected")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    
                    case .snippets:
                        SnippetsInspector(selectedLanguage: $selectedLanguage)
                            .inspectorColumnWidth(min: 260, ideal: 300, max: 340)
                    
                    case .collection:
                        CollectionInspector(
                            viewModel: collectionViewModel,
                            document: $document,
                            assetsFolder: document.assetsFolder?.resolvedURL()
                        )
                        .inspectorColumnWidth(min: 280, ideal: 320)
                    
                    case .none:
                        EmptyView()
                    }
                }
                .environmentObject(sdc)
            }
            .frame(minHeight: 400)
        }
        .onChange(of: document) { _, _ in
            // Auto-reload JSON with debounce
            guard !jsonPanelCollapsed else { return }
            jsonDebounceTask?.cancel()
            jsonDebounceTask = Task {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    generateJSON()
                }
            }
        }
        .onAppear {
            sdc.bind(using: modelContext)
            session.openDocumentCount += 1
            
            // Reset inspector selections for new document
            inspectorState.reset()
            
            // Proactively validate assets folder
            validateAssetsFolderOnOpen()
        }
        .task(id: fileURL) {
            guard let url = fileURL else { return }
            if $document.wrappedValue.title.isEmpty { $document.wrappedValue.title = url.deletingPathExtension().lastPathComponent }
            $document.wrappedValue.filePath = url
            let snapshot = document
            let r = await sdc.reconcileOnOpen(from: snapshot, fileURL: url)
            if case .failure(let e) = r { print("[ContentView] reconcile error: \(e)") }
            // Mark documents created via your launcher on first open.
            if document.createdAt == nil {
                document.createdAt = Date()
            }
        }
        .onDisappear {
            Task { _ = await sdc.flushSwiftDataChange(for: $document.wrappedValue.id) }
            session.openDocumentCount -= 1
            if session.openDocumentCount == 0 && launcherAutoOpen {
                openWindow(id: "launcher")
            }
            
            // Debounced cleanup of orphaned image assets
            Task {
                try? await Task.sleep(for: .seconds(5))
                await cleanupOrphanedAssets()
            }
        }
        .onChange(of: selectedLanguage) { _, new in
            print("selectedLanguage changed to", new as Any)
        }
        .sheet(isPresented: $showAssetFolderPrompt) {
            VStack(spacing: 20) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("Select Assets Folder")
                    .font(.headline)
                
                Text("This document needs an assets folder to store images and files. Please select a folder where assets will be saved.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Button("Cancel") {
                        showAssetFolderPrompt = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Select Folder") {
                        showAssetFolderPrompt = false
                        _ = AssetFolderManager.shared.ensureAssetsFolder(for: $document)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(30)
            .frame(width: 400)
        }
        .onAppear {
            generateJSON()
        }
        .onChange(of: jsonPanelCollapsed) { _, isCollapsed in
            if !isCollapsed {
                generateJSON()
            }
        }
    }
    
    // MARK: - JSON Panel
    
    private var jsonPanel: some View {
        VStack(spacing: 0) {
            if !jsonPanelCollapsed {
                // Drag handle (resize)
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 6)
                        .overlay(
                            Capsule()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 40, height: 3)
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if jsonPanelDragStartHeight == 0 {
                                jsonPanelDragStartHeight = jsonPanelHeight
                            }
                            let proposed = jsonPanelDragStartHeight - value.translation.height
                            jsonPanelHeight = max(100, min(1200, proposed))
                        }
                        .onEnded { _ in
                            jsonPanelDragStartHeight = 0
                        }
                )
            }

            // Header with toggle button and view mode
            HStack(spacing: 8) {
                Text("Document JSON")
                    .font(.headline)

                Spacer()

                if !jsonPanelCollapsed {
                    Picker("View", selection: $jsonPanelViewMode) {
                        ForEach(JSONPanelViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                Button {
                    withAnimation {
                        jsonPanelCollapsed.toggle()
                    }
                } label: {
                    Label(jsonPanelCollapsed ? "Show" : "Hide",
                          systemImage: jsonPanelCollapsed ? "chevron.up" : "chevron.down")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)

                if !jsonPanelCollapsed {
                    Button {
                        generateJSON()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        copyJSONToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            if !jsonPanelCollapsed {
                Divider()

                // JSON Content
                Group {
                    if let error = jsonError {
                        Text("Error: \(error)")
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        switch jsonPanelViewMode {
                        case .tree:
                            JSONOutlineView.from(document: document)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .background(Color(NSColor.textBackgroundColor))
                        case .raw:
                            ScrollView {
                                Text(jsonString)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.textBackgroundColor))
                        }
                    }
                }
            }
        }
    }
    
    private func generateJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(document)
            jsonData = data
            if let string = String(data: data, encoding: .utf8) {
                jsonString = string
                jsonError = nil
            } else {
                jsonError = "Failed to convert JSON data to string"
            }
        } catch {
            jsonError = error.localizedDescription
        }
    }
    
    private func copyJSONToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
    }
    
    // MARK: - Image Import Handler
    
    private func handleImageImport(_ image: NSImage) {
        // Store original in app data
        let imageID: UUID
        do {
            imageID = try ImageAssetManager.shared.storeOriginal(image, fileExtension: "png")
        } catch {
            print("Failed to store original image: \(error)")
            return
        }
        
        // Get or create assets folder
        guard let assetsFolder = document.assetsFolder ?? createAssetsFolderIfNeeded(),
              let assetsFolderURL = assetsFolder.resolvedURL() else {
            print("Failed to get assets folder")
            return
        }
        
        // Generate filename for edited version
        let editedFilename = "\(selectedImageLabel.filenameBase).jpg"
        let editedURL = assetsFolderURL.appendingPathComponent(editedFilename)
        
        // Render edited version with aspect ratio
        let targetAspect = selectedImageLabel.targetAspect(using: image)
        let options = CoverRenderOptions(
            targetAspect: targetAspect,
            targetMaxPixels: selectedImageLabel.preferredMaxPixels,
            output: .jpeg(0.95),
            enforceCover: true
        )
        
        do {
            if let renderedImage = CoverRender.renderCover(
                nsImage: image,
                options: options,
                userTransform: nil
            ) {
                try renderedImage.writeJPEG(to: editedURL, quality: 0.95)
                
                // Calculate relative path
                let relativePath = editedURL.relativePath(from: assetsFolderURL) ?? editedURL.lastPathComponent
                
                // Update document with new asset path
                document.images[selectedImageLabel] = AssetPath(
                    id: imageID,
                    path: relativePath
                )
            }
        } catch {
            print("Failed to save edited image: \(error)")
        }
    }
    
    // MARK: - Media Action Handlers
    
    private func handleRevertToOriginal() {
        guard let assetPath = document.images[selectedImageLabel] else { return }
        
        let result = ImageImportService.revertToOriginal(
            label: selectedImageLabel,
            assetPath: assetPath,
            document: document
        )
        
        if result.error == nil {
            document.images[selectedImageLabel] = result.assetPath
        }
    }
    
    private func handleClearImage() {
        guard let assetPath = document.images[selectedImageLabel],
              let assetsFolderURL = document.assetsFolder?.resolvedURL() else { return }
        
        // Delete using ImageImportService
        ImageImportService.deleteImage(assetPath: assetPath, assetsFolderURL: assetsFolderURL)
        
        // Remove from document
        document.images.removeValue(forKey: selectedImageLabel.storageKey)
        mediaImageEditorViewModel.removeImage()
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
    
    private func createAssetsFolderIfNeeded() -> AssetsFolderLocation? {
        guard let fileURL = fileURL else { return nil }
        
        let assetsFolderURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("Assets", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: assetsFolderURL, withIntermediateDirectories: true)
            
            // Request security-scoped bookmark
            guard assetsFolderURL.startAccessingSecurityScopedResource() else {
                return nil
            }
            defer { assetsFolderURL.stopAccessingSecurityScopedResource() }
            
            let bookmarkData = try assetsFolderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let location = AssetsFolderLocation(
                path: assetsFolderURL.path
            )
            document.assetsFolder = location
            
            // Store bookmark using BookmarkManager
            try? BookmarkManager.shared.store(
                bookmark: bookmarkData,
                forPath: assetsFolderURL.path,
                in: document.documentWrapper
            )
            return location
        } catch {
            print("Failed to create assets folder: \(error)")
            return nil
        }
    }

    @ViewBuilder
    private func detailView(for tab: SidebarTab) -> some View {
        switch tab {
        case .basicInfo:
            // Show main BasicInfo view - classification/details are in inspector
            BasicInfoTabView(document: $document)

        case .content:
            switch contentSubtab ?? .summary {
            case .summary:
                DocumentTextSection(
                    title: "Summary",
                    text: Binding(
                        get: { document.summary },
                        set: { document.summary = $0 }
                    )
                )
            case .description:
     
                DocumentTextSection(
                    title: "Description",
                    text: Binding(
                        get: { document.description ?? "" },
                        set: { document.description = $0 }
                    )
                )
                
            case .resources:
                ResourcesDetailView(document: $document)
                
                
            }
            
        

        case .media:
            MediaDetailView(
                document: $document,
                selectedImageLabel: $selectedImageLabel,
                imageEditorViewModel: mediaImageEditorViewModel
            )
            .navigationTitle(selectedImageLabel.title)

        case .collection:
            CollectionTabView(document: $document)
                .environmentObject(collectionViewModel)

        case .snippets:
            CodeSnippetsView(
                programmingLanguage: selectedLanguage ?? .swift,
                selectedSnippetID: $selectedSnippetID
            )
                .onAppear { print("Detail language:", selectedLanguage as Any) }
                .onChange(of: selectedLanguage) { _, new in
                    print("Detail sees language change:", new as Any)
                }
        }
    }
    
    @ViewBuilder
    private var secondarySidebar: some View {
        switch selection {
        case .basicInfo:
            // No secondary sidebar for BasicInfo - classification/details moved to inspector
            Text("Use inspector for classification and details")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

        case .content:
            List(ContentSubtab.allCases, selection: $contentSubtab) { sub in
                Text(sub.title)
                    .tag(sub)
            }
            .navigationTitle("Content")


        case .media:
            MediaSecondarySidebar(
                document: $document,
                selectedImageLabel: $selectedImageLabel
            )
            .navigationTitle("Media")

        case .collection:
            CollectionSidebarNew(
                document: $document,
                viewModel: collectionViewModel
            )
            .navigationTitle("Collection")

        case .snippets:
            SnippetSecondarySidebar(
                selectedLanguage: $selectedLanguage,
                selectedSnippetID: $selectedSnippetID
            )
            .navigationTitle("Snippets")

        case .none:
            Text("No secondary options")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Validation
    
    private func validateAssetsFolderOnOpen() {
        // Check if assets folder exists and is accessible
        guard let assetsFolder = document.assetsFolder,
              let path = assetsFolder.path else {
            // No assets folder set - this is OK for new documents
            return
        }
        
        // Try to resolve the URL with bookmark first
        var resolvedURL: URL?
        if let bookmarkResolved = BookmarkManager.shared.resolve(path: path, from: document.documentWrapper) {
            resolvedURL = bookmarkResolved
        } else if FileManager.default.fileExists(atPath: path) {
            // Bookmark failed but path exists - try direct access
            resolvedURL = URL(fileURLWithPath: path)
        }
        
        guard let url = resolvedURL else {
            // Folder doesn't exist or can't be accessed
            print("[ContentView] Assets folder not found: \(path)")
            showAssetsFolderPermissionDialog(for: path)
            return
        }
        
        // Verify write permissions by attempting to create a test file
        let testFileURL = url.appendingPathComponent(".folio_permission_test_\(UUID().uuidString)")
        let testData = Data("test".utf8)
        
        do {
            try testData.write(to: testFileURL)
            try FileManager.default.removeItem(at: testFileURL)
            // Success - we have write access
        } catch {
            // Write permission denied
            print("[ContentView] No write access to assets folder: \(error.localizedDescription)")
            showAssetsFolderPermissionDialog(for: path)
        }
    }
    
    private func showAssetsFolderPermissionDialog(for path: String) {
        DispatchQueue.main.async {
            _ = AssetFolderManager.shared.requestPermissionForExistingFolder(
                path: path,
                in: self.$document
            )
        }
    }
    
    private func cleanupOrphanedAssets() async {
        // Collect all active image IDs from current document
        var activeIDs = Set<UUID>()
        for (_, assetPath) in document.images {
            activeIDs.insert(assetPath.id)
        }
        
        // Add IDs from collection items
        for (_, section) in document.collection {
            for item in section.items {
                activeIDs.insert(item.thumbnail.id)
                if let filePath = item.filePath {
                    activeIDs.insert(filePath.id)
                }
            }
        }
        
        // Cleanup orphaned assets (excluding active IDs)
        await ImageAssetManager.shared.cleanupOrphans(excluding: activeIDs)
    }
}


// MARK: - Snippet Secondary Sidebar

struct SnippetSecondarySidebar: View {
    @Binding var selectedLanguage: ProgrammingLanguage?
    @Binding var selectedSnippetID: CodeSnippetID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Language picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(ProgrammingLanguage.allCases) { language in
                        Text(language.displayName).tag(language as ProgrammingLanguage?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding()
            
            Divider()
            
            // Functions list
            List(selection: $selectedSnippetID) {
                Section("Functions") {
                    ForEach(CodeSnippetID.allCases) { snippetID in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snippetTitle(for: snippetID))
                                .font(.body)
                            Text(snippetSummary(for: snippetID))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .tag(snippetID)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    private func snippetTitle(for id: CodeSnippetID) -> String {
        switch id {
        case .loadSummary:
            return "Load & View Structure"
        case .exportMetadata:
            return "Extract Metadata"
        }
    }
    
    private func snippetSummary(for id: CodeSnippetID) -> String {
        switch id {
        case .loadSummary:
            return "Display JSON structure with formatting"
        case .exportMetadata:
            return "Parse and extract specific fields"
        }
    }
}


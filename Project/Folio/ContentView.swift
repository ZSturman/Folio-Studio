//
//  ContentView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//


import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    
    @AppStorage("launcherAutoOpen") private var launcherAutoOpen = true
    @AppStorage("jsonPanelHeight") private var jsonPanelHeight: Double = 300
    @AppStorage("jsonPanelCollapsed") private var jsonPanelCollapsed: Bool = true
    
    @Binding var document: FolioDocument
    @EnvironmentObject var session: AppSession
    @StateObject private var sdc = SwiftDataCoordinator()
    @StateObject private var mediaImageEditorViewModel = ImageEditorViewModel()
    
    
    @State private var selection: SidebarTab? = .basicInfo

    @State private var basicInfoSubtab: BasicInfoSubtab? = .main
    @State private var contentSubtab:   ContentSubtab?   = .summary
    @State private var selectedLanguage: ProgrammingLanguage? = .swift
    @State private var selectedResourceIndex: Int?
    @StateObject private var collectionViewModel: CollectionViewModel
    @State private var selectedImageLabel: ImageLabel = .thumbnail
    @State private var jsonString: String = ""
    @State private var jsonError: String?
    @State private var showInspector: Bool = true
    
    var fileURL: URL?
    
    init(document: Binding<FolioDocument>, fileURL: URL?) {
        self._document = document
        self.fileURL = fileURL
        self._collectionViewModel = StateObject(wrappedValue: CollectionViewModel(
            document: document,
            assetsFolder: document.wrappedValue.assetsFolder?.resolvedURL(),
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
                        ScrollView {
                            detailView(for: selection)
                                .environmentObject(sdc)
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .automatic) {
                                if selection == .media {
                                    Button(action: {
                                        showInspector.toggle()
                                    }) {
                                        Label("Inspector", systemImage: "sidebar.right")
                                    }
                                    .help("Toggle Inspector")
                                }
                            }
                        }
                    } else {
                        Text("Select a Tab")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .inspector(isPresented: $showInspector) {
                if selection == .media, let jsonImage = document.images[selectedImageLabel] {
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
                        },
                        onCopyOriginal: {
                            handleCopyOriginal()
                        }
                    )
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 340)
                }
            }
            .frame(minHeight: 400)
            
            // Bottom: Resizable JSON panel
            jsonPanel
                .frame(height: jsonPanelCollapsed ? 30 : max(100, min(800, jsonPanelHeight)))
        }
        .onAppear {
            sdc.bind(using: modelContext)
            session.openDocumentCount += 1
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
        }
        .onChange(of: selectedLanguage) { _, new in
            print("selectedLanguage changed to", new as Any)
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
            // Header with toggle button
            HStack {
                Text("Document JSON")
                    .font(.headline)
                Spacer()
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
                if let error = jsonError {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Text(jsonString)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        // Get or create assets folder
        guard let assetsFolder = document.assetsFolder ?? createAssetsFolderIfNeeded(),
              let assetsFolderURL = assetsFolder.resolvedURL() else {
            print("Failed to get assets folder")
            return
        }
        
        // Create necessary subdirectories
        let originalImagesFolder = assetsFolderURL.appendingPathComponent("OriginalImages", isDirectory: true)
        let editedImagesFolder = assetsFolderURL.appendingPathComponent("EditedImages", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: originalImagesFolder, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: editedImagesFolder, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directories: \(error)")
            return
        }
        
        // Generate filename based on label
        let timestamp = Int(Date().timeIntervalSince1970)
        let baseFilename = "\(selectedImageLabel.filenameBase)_\(timestamp)"
        let originalURL = originalImagesFolder.appendingPathComponent("\(baseFilename).png")
        let editedURL = editedImagesFolder.appendingPathComponent("\(baseFilename).png")
        
        // Save original image
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to convert image to PNG")
            return
        }
        
        do {
            try pngData.write(to: originalURL)
            
            // Process and save edited version
            let targetAspect = selectedImageLabel.targetAspect(using: image)
            let options = CoverRenderOptions(
                targetAspect: targetAspect,
                targetMaxPixels: selectedImageLabel.preferredMaxPixels,
                output: .png,
                enforceCover: true
            )
            
            if let renderedImage = CoverRender.renderCover(
                nsImage: image,
                options: options,
                userTransform: nil
            ),
               let renderedTiff = renderedImage.tiffRepresentation,
               let renderedBitmap = NSBitmapImageRep(data: renderedTiff),
               let renderedPNG = renderedBitmap.representation(using: .png, properties: [:]) {
                try renderedPNG.write(to: editedURL)
                
                // Update document with new paths
                document.images[selectedImageLabel] = AssetPath(
                    pathToOriginal: originalURL.path,
                    pathToEdited: editedURL.path
                )
                
                // Create sidecar with default transform
                let sidecar = EditedSidecar(
                    transform: UserTransform(),
                    aspectOverride: targetAspect
                )
                EditedSidecarIO.save(sidecar, for: editedURL)
            }
        } catch {
            print("Failed to save image: \(error)")
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
        guard var current = document.images[selectedImageLabel] else { return }
        
        if !current.pathToEdited.isEmpty {
            let editedURL = URL(fileURLWithPath: current.pathToEdited)
            if FileManager.default.fileExists(atPath: editedURL.path) {
                try? FileManager.default.removeItem(at: editedURL)
            }
        }
        
        current.pathToOriginal = ""
        current.pathToEdited = ""
        document.images[selectedImageLabel] = current
        mediaImageEditorViewModel.removeImage()
    }
    
    private func handleCopyOriginal() {
        guard var current = document.images[selectedImageLabel],
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
            
            let destURL = uniqueURL(in: sourceImagesFolder, for: originalURL.lastPathComponent)
            if originalURL.standardizedFileURL != destURL.standardizedFileURL {
                try FileManager.default.copyItem(at: originalURL, to: destURL)
            }
            current.pathToOriginal = destURL.path
            document.images[selectedImageLabel] = current
        } catch {
            print("Failed to copy original: \(error)")
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
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            let location = AssetsFolderLocation(
                path: assetsFolderURL.path,
                bookmarkData: bookmarkData
            )
            document.assetsFolder = location
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
            switch basicInfoSubtab ?? .main {
            case .main:
                // your existing main basic info view
                BasicInfoTabView(document: $document)

            case .classification:
                // a different view or mode for classification
                BasicInfoClassificationView(document: $document)

            case .details:
                BasicInfoDetailsView(document: $document)
            }

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
            CodeSnippetsView(programmingLanguage: selectedLanguage ?? .swift)
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
            List(BasicInfoSubtab.allCases, selection: $basicInfoSubtab) { sub in
                Text(sub.title)
                    .tag(sub)
            }
            .navigationTitle("Basic Info")

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
            List(ProgrammingLanguage.allCases, selection: $selectedLanguage) { language in
                Text(language.displayName)
                    .tag(language)
            }
            .navigationTitle("Snippets")

        case .none:
            Text("No secondary options")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView(document: .constant(FolioDocument()), fileURL: nil)
        .environmentObject(AppSession())
        .modelContainer(for: FolioVersionedSchema.models, inMemory: true)
}


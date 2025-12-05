//
//  LauncherView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers


struct LauncherView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: AppSession
    
    @AppStorage("launcherAutoOpen") private var launcherAutoOpen = true
    
    @Query(sort: [SortDescriptor(\ProjectDoc.updatedAt, order: .reverse)])
    private var documents: [ProjectDoc]
    
    @State private var showFileNotFoundAlert = false
    @State private var missingDocument: ProjectDoc?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Folio").font(.largeTitle)
            Text("Open an existing document or create a new one.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Open…") {
                    DocumentActions.openExistingDocumentPanel()
                    // Don't dismiss - keep launcher open for easier workflow
                }
                .accessibilityIdentifier("Open...")
                
                Button("New…") {
                    DocumentActions.createNewDocumentWithSavePanel()
                    // Don't dismiss - keep launcher open for easier workflow
                }
                .accessibilityIdentifier("New...")
                .keyboardShortcut(.defaultAction)
            }
            
            if !documents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Documents")
                        .font(.headline)
                        .padding(.leading, 4)
                    
                    List {
                        ForEach(documents, id: \.self) { doc in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.title)
                                        .font(.body)
                                    Text(doc.filePath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openDocument(doc)
                            }
                            .contextMenu {
                                Button {
                                    openDocument(doc)
                                } label: {
                                    Label("Open", systemImage: "doc")
                                }
                                
                                Button {
                                    showInFinder(doc)
                                } label: {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    removeFromList(doc)
                                } label: {
                                    Label("Remove from List", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .frame(minHeight: 200)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 360)
        .alert("File Not Found", isPresented: $showFileNotFoundAlert, presenting: missingDocument) { doc in
            Button("Locate File") {
                relocateFile(for: doc)
            }
            Button("Remove from List", role: .destructive) {
                removeFromList(doc)
            }
            Button("Cancel", role: .cancel) {}
        } message: { doc in
            Text("The file '\(doc.title)' could not be found at:\n\(doc.filePath)\n\nWould you like to locate it or remove it from the list?")
        }
    }
    
    private func openDocument(_ doc: ProjectDoc) {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: doc.filePath) else {
            missingDocument = doc
            showFileNotFoundAlert = true
            return
        }
        
        // Check permissions
        if !FileManager.default.isReadableFile(atPath: doc.filePath) {
            grantAccess(to: doc)
            return
        }
        
        let url = URL(fileURLWithPath: doc.filePath)
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error = error {
                errorMessage = "Failed to open document: \(error.localizedDescription)"
            }
            // Keep launcher open - don't dismiss
        }
    }
    
    private func grantAccess(to doc: ProjectDoc) {
        let panel = NSOpenPanel()
        panel.message = "Grant permission to open '\(doc.title)'"
        panel.prompt = "Grant Access"
        panel.allowedContentTypes = [.folioDoc]
        panel.allowsOtherFileTypes = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: doc.filePath).deletingLastPathComponent()
        
        if panel.runModal() == .OK, let url = panel.url {
            // Try to open the selected file
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                if let error = error {
                    errorMessage = "Failed to open document: \(error.localizedDescription)"
                } else {
                    errorMessage = nil
                    // Update path if different
                    if url.path != doc.filePath {
                        doc.filePath = url.path
                        try? modelContext.save()
                    }
                }
            }
        }
    }
    
    private func showInFinder(_ doc: ProjectDoc) {
        let url = URL(fileURLWithPath: doc.filePath)
        
        if FileManager.default.fileExists(atPath: doc.filePath) {
            NSWorkspace.shared.selectFile(doc.filePath, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        } else {
            errorMessage = "File not found: \(doc.filePath)"
        }
    }
    
    private func removeFromList(_ doc: ProjectDoc) {
        modelContext.delete(doc)
        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to remove document: \(error.localizedDescription)"
        }
    }
    
    private func relocateFile(for doc: ProjectDoc) {
        let panel = NSOpenPanel()
        panel.title = "Locate '\(doc.title)'"
        panel.message = "Please select the relocated file"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.init(filenameExtension: "folioDoc") ?? .data]
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            // Update the path in SwiftData
            doc.filePath = url.path
            do {
                try modelContext.save()
                errorMessage = nil
                // Now try to open it
                openDocument(doc)
            } catch {
                errorMessage = "Failed to update file path: \(error.localizedDescription)"
            }
        }
    }
}

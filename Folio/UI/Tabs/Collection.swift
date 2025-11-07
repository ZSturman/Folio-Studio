//
//  Collection.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//


import SwiftUI
import AppKit

struct CollectionTabView: View {
    @Binding var document: FolioDocument

    @State private var errorMessage: String?
    @State private var showingAddCollection = false
    @State private var newCollectionName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let msg = errorMessage {
                Text(msg).foregroundColor(.red).font(.caption)
            }

            Divider()

            if document.assetsFolder == nil {
                gate
            } else {
                content
            }
        }
        .padding()
        .sheet(isPresented: $showingAddCollection) { addCollectionSheet }
    }

    // MARK: UI sections

    private var header: some View {
        HStack {
            Text("Assets Folder:")
            if let assetsFolder = document.assetsFolder {
                Text(assetsFolder.path)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("None selected").foregroundColor(.secondary)
            }
            Spacer()
            Button("Choose…") { pickAssetFolder() }
        }
    }

    private var gate: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select an assets folder to manage collections.")
                .foregroundColor(.secondary)
            Text("The app will create a Collections/ subfolder and organize items within it.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var content: some View {
        #if os(macOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Collections").font(.title3).bold()
                    Spacer()
                    Button {
                        newCollectionName = ""
                        showingAddCollection = true
                    } label: {
                        Label("Add Collection", systemImage: "plus")
                    }
                }
                ForEach(sortedCollectionKeys, id: \.self) { key in
                    DisclosureGroup {
                        CollectionDetailView(
                            document: $document,
                            initialCollectionName: key
                        )
                        .padding(.leading, 8)
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text(key).font(.headline)
                            Spacer()
                            if let count = document.collection[key]?.count {
                                Text("\(count) item\(count == 1 ? "" : "s")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Divider()
                }
                if sortedCollectionKeys.isEmpty {
                    Text("No collections yet. Add one to get started.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
        }
        #else
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Collections").font(.title3).bold()
                Spacer()
                Button {
                    newCollectionName = ""
                    showingAddCollection = true
                } label: {
                    Label("Add Collection", systemImage: "plus")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sortedCollectionKeys, id: \.self) { key in
                        NavigationLink {
                            CollectionDetailView(
                                document: $document,
                                initialCollectionName: key
                            )
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(key).font(.headline)
                                Spacer()
                                if let count = document.collection[key]?.count {
                                    Text("\(count) item\(count == 1 ? "" : "s")")
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 6)
                        }
                        Divider()
                    }
                    if sortedCollectionKeys.isEmpty {
                        Text("No collections yet. Add one to get started.")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        #endif
    }

    private var sortedCollectionKeys: [String] {
        document.collection.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: Add sheet

    private var addCollectionSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Collection").font(.headline)
            TextField("Collection name", text: $newCollectionName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addCollection() }

            HStack {
                Spacer()
                Button("Cancel") { showingAddCollection = false }
                Button("Create") { addCollection() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || document.assetsFolder == nil)
            }
        }
        .padding()
        .frame(minWidth: 420)
    }

    private func addCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard document.collection[name] == nil else {
            errorMessage = "Collection already exists."
            return
        }
        guard let assets = document.assetsFolder else { return }
        do {
            _ = try CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: name)
            document.collection[name] = []
            errorMessage = nil
            showingAddCollection = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Folder picker

    private func pickAssetFolder() {
        let panel = NSOpenPanel()
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            document.assetsFolder = url
            errorMessage = nil
        }
    }
}

#Preview {
    NavigationStack {
        CollectionTabView(document:.constant(FolioDocument()))
    }
}

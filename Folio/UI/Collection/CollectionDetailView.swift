//
//  CollectionDetailView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import Foundation

import SwiftUI
import UniformTypeIdentifiers

struct CollectionDetailView: View {
    @Binding var document: FolioDocument

    // We capture the initial key so we can lookup and also handle renames safely.
    let initialCollectionName: String

    @State private var workingName: String = ""
    @State private var errorMessage: String?

    // Computed binding to the items array for the collection key (which may change on rename).
    private var itemsBinding: Binding<[JSONCollectionItem]> {
        Binding<[JSONCollectionItem]>(
            get: {
                document.collection[workingName] ?? []
            },
            set: { newValue in
                document.collection[workingName] = newValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let msg = errorMessage {
                Text(msg).foregroundColor(.red).font(.caption)
            }

            Divider()

            HStack {
                Text("Items").font(.title3).bold()
                Spacer()
                Button {
                    addItem()
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .disabled(document.assetsFolder == nil)
            }

            if itemsBinding.wrappedValue.isEmpty {
                Text("No items yet. Add one to attach a file and thumbnail.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            ScrollView {
                #if os(macOS)
                VStack(spacing: 12) {
                    ForEach(itemsBinding.wrappedValue.indices, id: \.self) { idx in
                        let item = itemsBinding.wrappedValue[idx]
                        DisclosureGroup {
                            CollectionItemEditor(
                                document: $document,
                                item: Binding(
                                    get: { itemsBinding.wrappedValue[idx] },
                                    set: { newVal in
                                        var items = itemsBinding.wrappedValue
                                        items[idx] = newVal
                                        itemsBinding.wrappedValue = items
                                    }
                                ),
                                collectionName: workingName,
                                assetsFolder: document.assetsFolder,
                                onDelete: { deleteItem(at: idx) }
                            )
                        } label: {
                            HStack {
                                Image(systemName: "doc")
                                Text(item.label.isEmpty ? "New Item" : item.label)
                                    .font(.subheadline).bold()
                                Spacer()
                                let edited = item.filePath.pathToEdited
                                let original = item.filePath.pathToOriginal
                                if !edited.isEmpty {
                                    Text(URL(fileURLWithPath: edited).lastPathComponent)
                                        .foregroundStyle(.secondary)
                                } else if !original.isEmpty {
                                    Text(URL(fileURLWithPath: original).lastPathComponent)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Divider()
                    }
                }
                #else
                VStack(spacing: 12) {
                    ForEach(itemsBinding.wrappedValue.indices, id: \.self) { idx in
                        CollectionItemEditor(
                            document: $document,
                            item: Binding(
                                get: { itemsBinding.wrappedValue[idx] },
                                set: { newVal in
                                    var items = itemsBinding.wrappedValue
                                    items[idx] = newVal
                                    itemsBinding.wrappedValue = items
                                }
                            ),
                            collectionName: workingName,
                            assetsFolder: document.assetsFolder,
                            onDelete: { deleteItem(at: idx) }
                        )
                        Divider()
                    }
                }
                #endif
            }
        }
        .padding()
        .onAppear {
            workingName = initialCollectionName
        }
    }

    // MARK: Header with rename

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Collection") {
                TextField("Name", text: $workingName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { applyRename(from: initialCollectionName, to: workingName) }
                    .onChange(of: workingName) { _, new in
                        // Optional live rename. If you prefer onSubmit only, remove this.
                        // Safety: block empty name.
                        guard !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        applyRename(from: initialCollectionName, to: new)
                    }
            }
            Text("Folder: \(folderPathPreview)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var folderPathPreview: String {
        guard let assets = document.assetsFolder else { return "—" }
        let safe = CollectionFS.safeName(workingName)
        return CollectionFS.collectionsRoot(in: assets).appendingPathComponent(safe, isDirectory: true).path
    }

    // MARK: Actions

    private func applyRename(from old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard document.assetsFolder != nil else { return }
        guard old != trimmed else { return }

        // Protect against duplicate keys.
        if old != trimmed, document.collection[trimmed] != nil {
            errorMessage = "A collection named “\(trimmed)” already exists."
            workingName = old
            return
        }

        do {
            if let assets = document.assetsFolder {
                // Move folder on disk.
                let newFolder = try CollectionFS.renameCollectionFolder(assetsFolder: assets, oldName: old, newName: trimmed)

                // Rebase each item's edited paths and thumbnails.
                if var items = document.collection[old] {
                    let oldFolder = CollectionFS.collectionsRoot(in: assets).appendingPathComponent(CollectionFS.safeName(old), isDirectory: true)
                    for i in items.indices {
                        // Rebase edited file
                        items[i].filePath.pathToEdited = CollectionFS.rebaseEditedPath(
                            oldEditedPath: items[i].filePath.pathToEdited,
                            oldParent: oldFolder.appendingPathComponent(CollectionFS.safeName(items[i].label), isDirectory: true),
                            newParent: newFolder.appendingPathComponent(CollectionFS.safeName(items[i].label), isDirectory: true)
                        )
                        // Rebase thumbnail
                        items[i].thumbnail.pathToEdited = CollectionFS.rebaseEditedPath(
                            oldEditedPath: items[i].thumbnail.pathToEdited,
                            oldParent: oldFolder.appendingPathComponent(CollectionFS.safeName(items[i].label), isDirectory: true),
                            newParent: newFolder.appendingPathComponent(CollectionFS.safeName(items[i].label), isDirectory: true)
                        )
                    }
                    // Swap keys in the dictionary.
                    document.collection.removeValue(forKey: old)
                    document.collection[trimmed] = items
                } else {
                    // If old key had no items, just move the key.
                    document.collection.removeValue(forKey: old)
                    document.collection[trimmed] = document.collection[trimmed] ?? []
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            // Roll back UI name
            workingName = old
        }
    }

    private func addItem() {
        var items = itemsBinding.wrappedValue
        items.append(JSONCollectionItem())
        itemsBinding.wrappedValue = items
    }

    private func deleteItem(at index: Int) {
        // Optional: also remove the item's folder; safe to ignore errors.
        if let assets = document.assetsFolder {
            let colFolder = CollectionFS.collectionsRoot(in: assets).appendingPathComponent(CollectionFS.safeName(workingName), isDirectory: true)
            let item = itemsBinding.wrappedValue[index]
            let itemFolder = colFolder.appendingPathComponent(CollectionFS.safeName(item.label), isDirectory: true)
            try? FileManager.default.removeItem(at: itemFolder)
        }
        var items = itemsBinding.wrappedValue
        items.remove(at: index)
        itemsBinding.wrappedValue = items
    }
}

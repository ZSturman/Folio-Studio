//////
//////  CollectionDetailView.swift
//////  Folio
//////
//////  Created by Zachary Sturman on 11/7/25.
//////
////
////import Foundation
////
////import SwiftUI
////import UniformTypeIdentifiers
////
////struct CollectionDetailView: View {
////    @Binding var document: FolioDocument
////
////    // We capture the initial key so we can lookup and also handle renames safely.
////    let initialCollectionName: String
////
////    @State private var workingName: String = ""
////    @State private var errorMessage: String?
////
////    // Computed binding to the items array for the collection key (which may change on rename).
////    private var itemsBinding: Binding<[JSONCollectionItem]> {
////        Binding<[JSONCollectionItem]>(
////            get: {
////                document.collection[workingName] ?? []
////            },
////            set: { newValue in
////                document.collection[workingName] = newValue
////            }
////        )
////    }
////
////    var body: some View {
////        VStack(alignment: .leading, spacing: 12) {
////            header
////
////            if let msg = errorMessage {
////                Text(msg).foregroundColor(.red).font(.caption)
////            }
////
////            Divider()
////
////            HStack {
////                Text("Items").font(.title3).bold()
////                Spacer()
////                Button {
////                    addItem()
////                } label: {
////                    Label("Add Item", systemImage: "plus")
////                }
////                .disabled(document.assetsFolder == nil)
////            }
////
////            if itemsBinding.wrappedValue.isEmpty {
////                Text("No items yet. Add one to attach a file and thumbnail.")
////                    .foregroundStyle(.secondary)
////                    .padding(.vertical, 8)
////            }
////
////            ScrollView {
////
////                VStack(spacing: 12) {
////                    ForEach(Array(itemsBinding.wrappedValue.enumerated()), id: \.offset) { element in
////                        let idx = element.offset
////                        let item = element.element
//                        DisclosureGroup {
//                            CollectionItemEditor(
//                                document: $document,
//                                item: Binding(
//                                    get: { itemsBinding.wrappedValue[idx] },
//                                    set: { newVal in
//                                        var items = itemsBinding.wrappedValue
//                                        items[idx] = newVal
//                                        itemsBinding.wrappedValue = items
//                                    }
//                                ),
//                                collectionName: workingName,
//                                assetsFolder: document.assetsFolder,
//                                onDelete: { deleteItem(at: idx) }
//                            )
//                        } label: {
//                            HStack {
//                                if let thumbPath = item.thumbnail.pathToEdited, !thumbPath.isEmpty,
//                                   let nsImage = NSImage(contentsOf: URL(fileURLWithPath: thumbPath)) {
//                                    Image(nsImage: nsImage)
//                                        .resizable()
//                                        .aspectRatio(contentMode: .fill)
//                                        .frame(width: 24, height: 24)
//                                        .clipShape(RoundedRectangle(cornerRadius: 4))
//                                } else {
//                                    Image(systemName: "doc")
//                                        .frame(width: 24, height: 24)
//                                }
//                                
//                                Text(item.label.isEmpty ? "New Item" : item.label)
//                                    .font(.subheadline).bold()
//                                //                                Spacer()
//                                //                                let edited = item.filePath?.pathToEdited
//                                //                                let original = item.filePath?.pathToOriginal
//                                //                                if let edited, !edited.isEmpty {
//                                //                                    Text(URL(fileURLWithPath: edited).lastPathComponent)
//                                //                                        .foregroundStyle(.secondary)
//                                //                                } else if let original, !original.isEmpty {
//                                //                                    Text(URL(fileURLWithPath: original).lastPathComponent)
//                                //                                        .foregroundStyle(.secondary)
//                                //                                }
//                            }
//                        }
//                        Divider()
//                    }
//                }
////
////            }
////        }
////        .padding()
////        .onAppear {
////            workingName = initialCollectionName
////        }
////    }
////
////    // MARK: Header with rename
////
////    private var header: some View {
////        VStack(alignment: .leading, spacing: 8) {
////            LabeledContent("Collection") {
////                TextField("Name", text: $workingName)
////                    .textFieldStyle(.roundedBorder)
////                    .onSubmit { applyRename(from: initialCollectionName, to: workingName) }
////            }
////            Text("Folder: \(folderPathPreview)")
////                .font(.footnote)
////                .foregroundStyle(.secondary)
////        }
////    }
////
////    private var folderPathPreview: String {
////        guard let assets = document.assetsFolder else { return "—" }
////        let safe = CollectionFS.safeName(workingName)
////        return CollectionFS.collectionsRoot(in: assets).appendingPathComponent(safe, isDirectory: true).path
////    }
////
////    // MARK: Actions
////
////    private func applyRename(from old: String, to new: String) {
////        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
////        guard !trimmed.isEmpty else { return }
////        guard document.assetsFolder != nil else { return }
////        guard old != trimmed else { return }
////
////        // Protect against duplicate keys.
////        if old != trimmed, document.collection[trimmed] != nil {
////            errorMessage = "A collection named “\(trimmed)” already exists."
////            workingName = old
////            return
////        }
////
////        do {
////            if let assets = document.assetsFolder {
////                // Move folder on disk.
////                let newFolder = try CollectionFS.renameCollectionFolder(assetsFolder: assets, oldName: old, newName: trimmed)
////
////                // Rebase each item's edited paths and thumbnails.
////                if var items = document.collection[old] {
////                    let oldFolder = CollectionFS.collectionsRoot(in: assets).appendingPathComponent(CollectionFS.safeName(old), isDirectory: true)
////                    for i in items.indices {
////                        let label = items[i].label
////                        let oldParent = oldFolder.appendingPathComponent(CollectionFS.safeName(label), isDirectory: true)
////                        let newParent = newFolder.appendingPathComponent(CollectionFS.safeName(label), isDirectory: true)
////
////                        var item = items[i]
////
////                        // Rebase edited file, if it exists
////                        if let oldEdited = item.filePath?.pathToEdited {
////                            item.filePath?.pathToEdited = CollectionFS.rebaseEditedPath(
////                                oldEditedPath: oldEdited,
////                                oldParent: oldParent,
////                                newParent: newParent
////                            )
////                        }
////
////                        // Rebase thumbnail
////                        item.thumbnail.pathToEdited = CollectionFS.rebaseEditedPath(
////                            oldEditedPath: item.thumbnail.pathToEdited,
////                            oldParent: oldParent,
////                            newParent: newParent
////                        )
////
////                        items[i] = item
////                    }
////                    // Swap keys in the dictionary.
////                    document.collection.removeValue(forKey: old)
////                    document.collection[trimmed] = items
////                } else {
////                    // If old key had no items, just move the key.
////                    document.collection.removeValue(forKey: old)
////                    document.collection[trimmed] = document.collection[trimmed] ?? []
////                }
////            }
////            errorMessage = nil
////        } catch {
////            errorMessage = error.localizedDescription
////            // Roll back UI name
////            workingName = old
////        }
////    }
////
////    private func addItem() {
////        var items = itemsBinding.wrappedValue
////        items.append(JSONCollectionItem())
////        itemsBinding.wrappedValue = items
////    }
////
////    private func deleteItem(at index: Int) {
////        // Optional: also remove the item's folder; safe to ignore errors.
////        if let assets = document.assetsFolder {
////            let colFolder = CollectionFS.collectionsRoot(in: assets).appendingPathComponent(CollectionFS.safeName(workingName), isDirectory: true)
////            let item = itemsBinding.wrappedValue[index]
////            let itemFolder = colFolder.appendingPathComponent(CollectionFS.safeName(item.label), isDirectory: true)
////            try? FileManager.default.removeItem(at: itemFolder)
////        }
////        var items = itemsBinding.wrappedValue
////        items.remove(at: index)
////        itemsBinding.wrappedValue = items
////    }
////}
//

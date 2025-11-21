//
//  CollectionViewModel.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI
import Combine

/// ViewModel for managing Collection and CollectionItem state and mutations.
/// Eliminates "Publishing changes from within view updates" by handling all
/// document mutations through explicit methods outside of view update cycles.
@MainActor
class CollectionViewModel: ObservableObject {
    // MARK: - Published State
    
    /// Currently selected collection name (nil if no collection selected)
    @Published var selectedCollectionName: String?
    
    /// Currently selected item ID (nil if no item selected or collection-level view)
    @Published var selectedItemId: UUID?
    
    /// Whether the inspector panel should be visible
    @Published var showInspector: Bool = false
    
    // MARK: - Private State
    
    /// Reference to the document binding for mutations
    private var documentBinding: Binding<FolioDocument>
    
    /// Assets folder URL for file operations
    private var assetsFolder: URL?
    
    /// Undo manager for registering undoable actions
    var undoManager: UndoManager?
    
    // MARK: - Initialization
    
    init(document: Binding<FolioDocument>, assetsFolder: URL?, undoManager: UndoManager?) {
        self.documentBinding = document
        self.assetsFolder = assetsFolder
        self.undoManager = undoManager
    }
    
    // MARK: - Binding Updates
    
    /// Updates the document binding and assets folder from the parent view
    /// This is crucial because StateObject holds the initial binding captured at creation time,
    /// which becomes stale if the parent view is recreated with a new binding.
    func updateBinding(_ document: Binding<FolioDocument>) {
        self.documentBinding = document
        self.assetsFolder = document.wrappedValue.resolvedAssetsFolderURL()
    }
    
    // MARK: - Private Helpers
    
    /// Updates a collection section and triggers SwiftUI change detection
    /// by replacing the entire document (needed for deep struct mutations)
    private func updateCollectionSection(_ name: String, with section: CollectionSection) {
        objectWillChange.send()
        var updatedDocument = documentBinding.wrappedValue
        updatedDocument.collection[name] = section
        updatedDocument.updatedAt = Date() // Update timestamp
        documentBinding.wrappedValue = updatedDocument
    }
    
    /// Removes a collection and triggers SwiftUI change detection
    private func removeCollection(_ name: String) {
        objectWillChange.send()
        var updatedDocument = documentBinding.wrappedValue
        updatedDocument.collection.removeValue(forKey: name)
        updatedDocument.updatedAt = Date() // Update timestamp
        documentBinding.wrappedValue = updatedDocument
    }
    
    /// Adds a collection and triggers SwiftUI change detection
    private func addCollection(_ name: String, section: CollectionSection) {
        objectWillChange.send()
        var updatedDocument = documentBinding.wrappedValue
        updatedDocument.collection[name] = section
        updatedDocument.updatedAt = Date() // Update timestamp
        documentBinding.wrappedValue = updatedDocument
    }
    
    // MARK: - Computed Properties
    
    /// The currently selected collection section
    var selectedCollection: CollectionSection? {
        guard let name = selectedCollectionName else { return nil }
        return documentBinding.wrappedValue.collection[name]
    }
    
    /// The currently selected collection item
    var selectedItem: JSONCollectionItem? {
        guard let section = selectedCollection,
              let itemId = selectedItemId else {
            print("[CollectionViewModel] ⚠️ selectedItem: no section or itemId")
            return nil
        }
        let item = section.items.first { $0.id == itemId }
        if let item = item {
            print("[CollectionViewModel] 🔍 selectedItem returned:")
            print("  - ID: \(item.id)")
            print("  - Label: \(item.label)")
            print("  - Summary: \(item.summary ?? "nil")")
            print("  - Thumbnail: \(item.thumbnail.path)")
        } else {
            print("[CollectionViewModel] ⚠️ selectedItem: item not found with ID \(itemId)")
        }
        return item
    }
    
    /// Index of the currently selected item in the items array
    private var selectedItemIndex: Int? {
        guard let section = selectedCollection,
              let itemId = selectedItemId else { return nil }
        return section.items.firstIndex { $0.id == itemId }
    }
    
    // MARK: - Collection Management
    
    /// Creates a new collection with a default empty item
    func createCollection(name: String = "New Collection") {
        var trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            trimmed = "New Collection"
        }
        
        // Ensure unique name
        var finalName = trimmed
        var counter = 1
        while documentBinding.wrappedValue.collection[finalName] != nil {
            finalName = "\(trimmed) \(counter)"
            counter += 1
        }
        
        let newItem = JSONCollectionItem(label: "New Item")
        let newSection = CollectionSection(images: [:], items: [newItem])
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
            vm.selectedCollectionName = nil
            vm.selectedItemId = nil
        }
        undoManager?.setActionName("Create Collection")
        
        // Mutate document using helper
        addCollection(finalName, section: newSection)
        objectWillChange.send()
        
        // Select the new collection
        selectedCollectionName = finalName
        selectedItemId = nil
        showInspector = false
        
        // Create folder if assets folder exists
        if let assets = assetsFolder {
            _ = try? CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: finalName)
        }
    }
    
    /// Renames the currently selected collection
    func renameCollection(to newName: String) {
        guard let oldName = selectedCollectionName else { return }
        
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        
        // Prevent duplicate names
        if documentBinding.wrappedValue.collection[trimmed] != nil {
            return
        }
        
        guard let section = documentBinding.wrappedValue.collection[oldName] else { return }
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        let oldSelection = oldName
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
            vm.selectedCollectionName = oldSelection
        }
        undoManager?.setActionName("Rename Collection")
        
        // Rename in file system and rebase paths
        if let assets = assetsFolder {
            do {
                let newFolder = try CollectionFS.renameCollectionFolder(
                    assetsFolder: assets,
                    oldName: oldName,
                    newName: trimmed
                )
                
                let oldFolder = CollectionFS.collectionsRoot(in: assets)
                    .appendingPathComponent(CollectionFS.safeName(oldName), isDirectory: true)
                
                // Rebase all item paths - keep them relative
                var updatedSection = section
                for (index, item) in section.items.enumerated() {
                    let label = item.label
                    let newParent = newFolder.appendingPathComponent(CollectionFS.safeName(label), isDirectory: true)
                    
                    // Rebase file path to relative
                    if let fp = item.filePath, !fp.path.isEmpty {
                        let filename = URL(fileURLWithPath: fp.path).lastPathComponent
                        let newRelativePath = newParent.relativePath(from: assets) ?? "Collections/\(CollectionFS.safeName(trimmed))/\(CollectionFS.safeName(label))"
                        updatedSection.items[index].filePath?.path = "\(newRelativePath)/\(filename)"
                    }
                    
                    // Rebase thumbnail path to relative
                    if !item.thumbnail.path.isEmpty {
                        let filename = URL(fileURLWithPath: item.thumbnail.path).lastPathComponent
                        let newRelativePath = newParent.relativePath(from: assets) ?? "Collections/\(CollectionFS.safeName(trimmed))/\(CollectionFS.safeName(label))"
                        updatedSection.items[index].thumbnail.path = "\(newRelativePath)/\(filename)"
                    }
                }
                
                // Update document using helpers
                removeCollection(oldName)
                addCollection(trimmed, section: updatedSection)
                objectWillChange.send()
                
                // Update bookmarks for all rebased paths
                if let wrapper = documentBinding.wrappedValue.documentWrapper {
                    for item in updatedSection.items {
                        if let fp = item.filePath, !fp.path.isEmpty {
                            let oldPath = fp.path.replacingOccurrences(of: CollectionFS.safeName(trimmed), with: CollectionFS.safeName(oldName))
                            try? BookmarkManager.shared.updateKey(from: oldPath, to: fp.path, in: wrapper)
                        }
                        if !item.thumbnail.path.isEmpty {
                            let oldPath = item.thumbnail.path.replacingOccurrences(of: CollectionFS.safeName(trimmed), with: CollectionFS.safeName(oldName))
                            try? BookmarkManager.shared.updateKey(from: oldPath, to: item.thumbnail.path, in: wrapper)
                        }
                    }
                }
                
            } catch {
                print("Error renaming collection folder: \(error)")
                // Still update the collection name in document even if folder rename fails
                removeCollection(oldName)
                addCollection(trimmed, section: section)
                objectWillChange.send()
            }
        } else {
            // No assets folder, just rename in document
            removeCollection(oldName)
            addCollection(trimmed, section: section)
            objectWillChange.send()
        }
        
        // Update selection
        selectedCollectionName = trimmed
    }
    
    /// Deletes the currently selected collection
    func deleteCollection() {
        guard let name = selectedCollectionName else { return }
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        let oldSelection = name
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
            vm.selectedCollectionName = oldSelection
        }
        undoManager?.setActionName("Delete Collection")
        
        // Mutate document using helper
        removeCollection(name)
        objectWillChange.send()
        
        // Clear selection
        selectedCollectionName = nil
        selectedItemId = nil
        showInspector = false
    }
    
    /// Updates collection-level images
    func updateCollectionImage(key: String, assetPath: AssetPath?) {
        guard let name = selectedCollectionName else { return }
        guard var section = documentBinding.wrappedValue.collection[name] else { return }
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
        }
        undoManager?.setActionName("Update Collection Image")
        
        // Update section
        section.images[key] = assetPath
        updateCollectionSection(name, with: section)
        objectWillChange.send()
    }
    
    // MARK: - Item Management
    
    /// Selects a collection item and auto-opens the inspector
    func selectItem(id: UUID) {
        selectedItemId = id
        showInspector = true
    }
    
    /// Deselects the current item and closes the inspector
    func deselectItem() {
        selectedItemId = nil
        showInspector = false
    }
    
    /// Adds a new item to the currently selected collection
    func addItem() {
        guard let name = selectedCollectionName else { return }
        guard var section = documentBinding.wrappedValue.collection[name] else { return }
        
        let newItem = JSONCollectionItem(
            label: "New Item",
            order: section.items.count
        )
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
            vm.selectedItemId = nil
        }
        undoManager?.setActionName("Add Item")
        
        // Add item
        section.items.append(newItem)
        updateCollectionSection(name, with: section)
        objectWillChange.send()
        
        // Select and show in inspector
        selectedItemId = newItem.id
        showInspector = true
        
        // Create item folder if assets folder exists
        if let assets = assetsFolder {
            let colFolder = CollectionFS.collectionsRoot(in: assets)
                .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
            _ = try? CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: newItem.label)
        }
    }
    
    /// Deletes the currently selected item
    func deleteItem() {
        guard let name = selectedCollectionName,
              let itemId = selectedItemId else { return }
        guard var section = documentBinding.wrappedValue.collection[name] else { return }
        guard let index = section.items.firstIndex(where: { $0.id == itemId }) else { return }
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        let oldItemId = itemId
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
            vm.selectedItemId = oldItemId
        }
        undoManager?.setActionName("Delete Item")
        
        // Remove item
        section.items.remove(at: index)
        updateCollectionSection(name, with: section)
        objectWillChange.send()
        
        // Deselect
        selectedItemId = nil
        showInspector = false
    }
    
    /// Updates a specific field of the currently selected item
    func updateItem(_ update: (inout JSONCollectionItem) -> Void) {
        print("[CollectionViewModel] 🔄 updateItem called")
        guard let name = selectedCollectionName,
              let index = selectedItemIndex else {
            print("  ❌ No selected collection or item index")
            return
        }
        guard var section = documentBinding.wrappedValue.collection[name] else {
            print("  ❌ Could not find section: \(name)")
            return
        }
        
        let itemBefore = section.items[index]
        print("  📝 Item before update:")
        print("    - ID: \(itemBefore.id)")
        print("    - Label: \(itemBefore.label)")
        print("    - Summary: \(itemBefore.summary ?? "nil")")
        print("    - Type: \(itemBefore.type)")
        print("    - URL: \(itemBefore.url ?? "nil")")
        print("    - Thumbnail: \(itemBefore.thumbnail.path)")
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
        }
        
        // Apply update
        update(&section.items[index])
        
        let itemAfter = section.items[index]
        print("  📝 Item after update:")
        print("    - Label: \(itemAfter.label)")
        print("    - Summary: \(itemAfter.summary ?? "nil")")
        print("    - Type: \(itemAfter.type)")
        print("    - URL: \(itemAfter.url ?? "nil")")
        print("    - Thumbnail: \(itemAfter.thumbnail.path)")
        
        // CRITICAL: Use the modified section, don't re-read from binding
        updateCollectionSection(name, with: section)
        
        print("  ✅ Document updated and change published")
        
        // Verify the update stuck
        if let verifySection = documentBinding.wrappedValue.collection[name],
           let verifyItem = verifySection.items.first(where: { $0.id == section.items[index].id }) {
            print("  🔍 Verification - item in document now has:")
            print("    - Label: \(verifyItem.label)")
            print("    - Summary: \(verifyItem.summary ?? "nil")")
            print("    - Thumbnail: \(verifyItem.thumbnail.path)")
        } else {
            print("  ❌ Verification failed - couldn't find item in document!")
        }
    }
    
    /// Updates the label of the currently selected item with file system operations
    func updateItemLabel(to newLabel: String) {
        print("[CollectionViewModel] 🏷️ updateItemLabel to: '\(newLabel)'")
        guard let name = selectedCollectionName,
              let index = selectedItemIndex else {
            print("  ❌ No selected collection or item index")
            return
        }
        guard var section = documentBinding.wrappedValue.collection[name] else {
            print("  ❌ Could not find section: \(name)")
            return
        }
        
        let oldLabel = section.items[index].label
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldLabel else {
            print("  ℹ️ Label unchanged or empty")
            return
        }
        
        print("  🔄 Changing label from '\(oldLabel)' to '\(trimmed)'")
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
        }
        undoManager?.setActionName("Rename Item")
        
        // Update label
        section.items[index].label = trimmed
        
        // Rename folder and rebase paths if assets folder exists
        if let assets = assetsFolder {
            print("  📂 Renaming folder in assets...")
            let colFolder = CollectionFS.collectionsRoot(in: assets)
                .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
            
            do {
                let oldFolder = colFolder.appendingPathComponent(CollectionFS.safeName(oldLabel), isDirectory: true)
                let newFolder = try CollectionFS.renameItemFolder(
                    collectionFolder: colFolder,
                    oldLabel: oldLabel,
                    newLabel: trimmed
                )
                print("  ✅ Folder renamed successfully")
                print("    - Old: \(oldFolder.path)")
                print("    - New: \(newFolder.path)")
                
                // Rebase file path - ensure we keep it relative
                if let fp = section.items[index].filePath,
                   !fp.path.isEmpty {
                    let oldPath = fp.path
                    // Get the filename from the old path
                    let filename = URL(fileURLWithPath: oldPath).lastPathComponent
                    // Build new relative path: Collections/CollectionName/NewItemLabel/filename
                    let newRelativePath = newFolder.relativePath(from: assets) ?? "Collections/\(CollectionFS.safeName(name))/\(CollectionFS.safeName(trimmed))"
                    section.items[index].filePath?.path = "\(newRelativePath)/\(filename)"
                    
                    print("  🔄 File path rebased:")
                    print("    - Old: \(oldPath)")
                    print("    - New: \(section.items[index].filePath?.path ?? "nil")")
                    
                    // Update bookmark
                    if let wrapper = documentBinding.wrappedValue.documentWrapper,
                       let newPath = section.items[index].filePath?.path {
                        try? BookmarkManager.shared.updateKey(from: oldPath, to: newPath, in: wrapper)
                    }
                }
                
                // Rebase thumbnail path - ensure we keep it relative
                if !section.items[index].thumbnail.path.isEmpty {
                    let oldPath = section.items[index].thumbnail.path
                    // Get the filename from the old path
                    let filename = URL(fileURLWithPath: oldPath).lastPathComponent
                    // Build new relative path: Collections/CollectionName/NewItemLabel/filename
                    let newRelativePath = newFolder.relativePath(from: assets) ?? "Collections/\(CollectionFS.safeName(name))/\(CollectionFS.safeName(trimmed))"
                    section.items[index].thumbnail.path = "\(newRelativePath)/\(filename)"
                    
                    print("  🔄 Thumbnail path rebased:")
                    print("    - Old: \(oldPath)")
                    print("    - New: \(section.items[index].thumbnail.path)")
                    
                    // Update bookmark
                    if let wrapper = documentBinding.wrappedValue.documentWrapper {
                        let newPath = section.items[index].thumbnail.path
                        try? BookmarkManager.shared.updateKey(from: oldPath, to: newPath, in: wrapper)
                    }
                }
            } catch {
                print("  ⚠️ Error renaming item folder: \(error)")
            }
        }
        
        // CRITICAL: Replace entire document to trigger SwiftUI change detection
        var updatedDocument = documentBinding.wrappedValue
        updatedDocument.collection[name] = section
        documentBinding.wrappedValue = updatedDocument
        
        objectWillChange.send()
        print("  ✅ Label update complete")
    }
    
    /// Reorders items in the collection
    func moveItems(from source: IndexSet, to destination: Int) {
        guard let name = selectedCollectionName else { return }
        guard var section = documentBinding.wrappedValue.collection[name] else { return }
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
        }
        undoManager?.setActionName("Reorder Items")
        
        // Move items
        section.items.move(fromOffsets: source, toOffset: destination)
        
        // Update order values
        for (index, _) in section.items.enumerated() {
            section.items[index].order = index
        }
        
        updateCollectionSection(name, with: section)
        objectWillChange.send()
    }
    
    /// Copies a file to the collection's assets folder
    func copyFileToAssets(from sourceURL: URL) {
        guard let name = selectedCollectionName,
              let index = selectedItemIndex,
              let assets = assetsFolder else { return }
        guard var section = documentBinding.wrappedValue.collection[name] else { return }
        
        let itemLabel = section.items[index].label
        let colFolder = CollectionFS.collectionsRoot(in: assets)
            .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
        
        do {
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: itemLabel)
            let destURL = try CollectionFS.copyWithCollision(from: sourceURL, to: itemFolder)
            
            // Register undo
            let oldDocument = documentBinding.wrappedValue
            undoManager?.registerUndo(withTarget: self) { vm in
                vm.documentBinding.wrappedValue = oldDocument
            }
            undoManager?.setActionName("Copy File to Assets")
            
            // Update file path - calculate relative path from assets folder
            let relativePath = destURL.relativePath(from: assets) ?? destURL.lastPathComponent
            section.items[index].filePath = AssetPath(id: UUID(), path: relativePath)
            updateCollectionSection(name, with: section)
            objectWillChange.send()
            
        } catch {
            print("Error copying file to assets: \(error)")
        }
    }
}


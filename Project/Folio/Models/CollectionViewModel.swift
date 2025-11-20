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
    
    // MARK: - Computed Properties
    
    /// The currently selected collection section
    var selectedCollection: CollectionSection? {
        guard let name = selectedCollectionName else { return nil }
        return documentBinding.wrappedValue.collection[name]
    }
    
    /// The currently selected collection item
    var selectedItem: JSONCollectionItem? {
        guard let section = selectedCollection,
              let itemId = selectedItemId else { return nil }
        return section.items.first { $0.id == itemId }
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
        
        // Mutate document
        documentBinding.wrappedValue.collection[finalName] = newSection
        
        // Select the new collection
        selectedCollectionName = finalName
        selectedItemId = nil
        showInspector = false
        
        // Create folder if assets folder exists
        if let assets = assetsFolder {
            try? CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: finalName)
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
                
                // Rebase all item paths
                var updatedSection = section
                for (index, item) in section.items.enumerated() {
                    let label = item.label
                    let oldParent = oldFolder.appendingPathComponent(CollectionFS.safeName(label), isDirectory: true)
                    let newParent = newFolder.appendingPathComponent(CollectionFS.safeName(label), isDirectory: true)
                    
                    if let fp = item.filePath, !fp.pathToEdited.isEmpty {
                        updatedSection.items[index].filePath?.pathToEdited = CollectionFS.rebaseEditedPath(
                            oldEditedPath: fp.pathToEdited,
                            oldParent: oldParent,
                            newParent: newParent
                        )
                    }
                    
                    if !item.thumbnail.pathToEdited.isEmpty {
                        updatedSection.items[index].thumbnail.pathToEdited = CollectionFS.rebaseEditedPath(
                            oldEditedPath: item.thumbnail.pathToEdited,
                            oldParent: oldParent,
                            newParent: newParent
                        )
                    }
                }
                
                // Update document
                documentBinding.wrappedValue.collection.removeValue(forKey: oldName)
                documentBinding.wrappedValue.collection[trimmed] = updatedSection
                
            } catch {
                print("Error renaming collection folder: \(error)")
                // Still update the collection name in document even if folder rename fails
                documentBinding.wrappedValue.collection.removeValue(forKey: oldName)
                documentBinding.wrappedValue.collection[trimmed] = section
            }
        } else {
            // No assets folder, just rename in document
            documentBinding.wrappedValue.collection.removeValue(forKey: oldName)
            documentBinding.wrappedValue.collection[trimmed] = section
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
        
        // Mutate document
        documentBinding.wrappedValue.collection.removeValue(forKey: name)
        
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
        documentBinding.wrappedValue.collection[name] = section
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
        documentBinding.wrappedValue.collection[name] = section
        
        // Select and show in inspector
        selectedItemId = newItem.id
        showInspector = true
        
        // Create item folder if assets folder exists
        if let assets = assetsFolder {
            let colFolder = CollectionFS.collectionsRoot(in: assets)
                .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
            try? CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: newItem.label)
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
        documentBinding.wrappedValue.collection[name] = section
        
        // Deselect
        selectedItemId = nil
        showInspector = false
    }
    
    /// Updates a specific field of the currently selected item
    func updateItem(_ update: (inout JSONCollectionItem) -> Void) {
        guard let name = selectedCollectionName,
              let index = selectedItemIndex else { return }
        guard var section = documentBinding.wrappedValue.collection[name] else { return }
        
        // Register undo
        let oldDocument = documentBinding.wrappedValue
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.documentBinding.wrappedValue = oldDocument
        }
        
        // Apply update
        update(&section.items[index])
        documentBinding.wrappedValue.collection[name] = section
    }
    
    /// Updates the label of the currently selected item with file system operations
    func updateItemLabel(to newLabel: String) {
        guard let name = selectedCollectionName,
              let index = selectedItemIndex else { return }
        guard var section = documentBinding.wrappedValue.collection[name] else { return }
        
        let oldLabel = section.items[index].label
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldLabel else { return }
        
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
            let colFolder = CollectionFS.collectionsRoot(in: assets)
                .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
            
            do {
                let oldFolder = colFolder.appendingPathComponent(CollectionFS.safeName(oldLabel), isDirectory: true)
                let newFolder = try CollectionFS.renameItemFolder(
                    collectionFolder: colFolder,
                    oldLabel: oldLabel,
                    newLabel: trimmed
                )
                
                // Rebase file path
                if let fp = section.items[index].filePath,
                   !fp.pathToEdited.isEmpty {
                    section.items[index].filePath?.pathToEdited = CollectionFS.rebaseEditedPath(
                        oldEditedPath: fp.pathToEdited,
                        oldParent: oldFolder,
                        newParent: newFolder
                    )
                }
                
                // Rebase thumbnail path
                if !section.items[index].thumbnail.pathToEdited.isEmpty {
                    section.items[index].thumbnail.pathToEdited = CollectionFS.rebaseEditedPath(
                        oldEditedPath: section.items[index].thumbnail.pathToEdited,
                        oldParent: oldFolder,
                        newParent: newFolder
                    )
                }
            } catch {
                print("Error renaming item folder: \(error)")
            }
        }
        
        documentBinding.wrappedValue.collection[name] = section
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
        
        documentBinding.wrappedValue.collection[name] = section
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
            
            // Update file path
            section.items[index].filePath = AssetPath(pathToEdited: destURL.path)
            documentBinding.wrappedValue.collection[name] = section
            
        } catch {
            print("Error copying file to assets: \(error)")
        }
    }
}

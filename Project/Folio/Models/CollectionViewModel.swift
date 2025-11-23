//
//  CollectionViewModel.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI
import Combine

/// ViewModel for managing Collection selection state.
/// Document mutations are handled via methods that take a Binding<FolioDocument>,
/// ensuring we always operate on the source of truth.
@MainActor
class CollectionViewModel: ObservableObject {
    // MARK: - Published State
    
    /// Currently selected collection name (nil if no collection selected)
    @Published var selectedCollectionName: String?
    
    /// Currently selected item ID (nil if no item selected or collection-level view)
    @Published var selectedItemId: UUID?
    
    /// Whether the inspector panel should be visible
    @Published var showInspector: Bool = false
    
    /// Undo manager for registering undoable actions
    var undoManager: UndoManager?
    
    // MARK: - Initialization
    
    init(undoManager: UndoManager?) {
        self.undoManager = undoManager
    }
    
    // MARK: - Helpers
    
    func selectedCollection(in document: FolioDocument) -> CollectionSection? {
        guard let name = selectedCollectionName else { return nil }
        return document.collection[name]
    }
    
    func selectedItem(in document: FolioDocument) -> JSONCollectionItem? {
        guard let section = selectedCollection(in: document),
              let itemId = selectedItemId else { return nil }
        return section.items.first { $0.id == itemId }
    }
    
    // MARK: - Collection Management
    
    /// Creates a new collection with a default empty item
    func createCollection(document: Binding<FolioDocument>) {
        var trimmed = "New Collection"
        
        // Ensure unique name
        var finalName = trimmed
        var counter = 1
        while document.wrappedValue.collection[finalName] != nil {
            finalName = "\(trimmed) \(counter)"
            counter += 1
        }
        
        let newItem = JSONCollectionItem(label: "New Item")
        let newSection = CollectionSection(images: [:], items: [newItem])
        
        // Mutate document
        document.wrappedValue.collection[finalName] = newSection
        document.wrappedValue.updatedAt = Date()
        
        // Select the new collection
        selectedCollectionName = finalName
        selectedItemId = nil
        showInspector = false
        
        // Create folder if assets folder exists
        if let assets = document.wrappedValue.resolvedAssetsFolderURL() {
            _ = try? CollectionFS.ensureCollectionFolder(assetsFolder: assets, name: finalName)
        }
    }
    
    /// Renames the currently selected collection
    func renameCollection(to newName: String, document: Binding<FolioDocument>) {
        guard let oldName = selectedCollectionName else { return }
        
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        
        // Prevent duplicate names
        if document.wrappedValue.collection[trimmed] != nil {
            return
        }
        
        guard let section = document.wrappedValue.collection[oldName] else { return }
        
        let assetsFolder = document.wrappedValue.resolvedAssetsFolderURL()
        
        // Rename in file system and rebase paths
        if let assets = assetsFolder {
            do {
                let newFolder = try CollectionFS.renameCollectionFolder(
                    assetsFolder: assets,
                    oldName: oldName,
                    newName: trimmed
                )
                
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
                
                // Update document
                document.wrappedValue.collection.removeValue(forKey: oldName)
                document.wrappedValue.collection[trimmed] = updatedSection
                document.wrappedValue.updatedAt = Date()
                
                // Update bookmarks for all rebased paths
                if let wrapper = document.wrappedValue.documentWrapper {
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
                document.wrappedValue.collection.removeValue(forKey: oldName)
                document.wrappedValue.collection[trimmed] = section
                document.wrappedValue.updatedAt = Date()
            }
        } else {
            // No assets folder, just rename in document
            document.wrappedValue.collection.removeValue(forKey: oldName)
            document.wrappedValue.collection[trimmed] = section
            document.wrappedValue.updatedAt = Date()
        }
        
        // Update selection
        selectedCollectionName = trimmed
    }
    
    /// Deletes the currently selected collection
    func deleteCollection(document: Binding<FolioDocument>) {
        guard let name = selectedCollectionName else { return }
        
        // Remove collection folder from file system if it exists
        if let assets = document.wrappedValue.resolvedAssetsFolderURL() {
            let colFolder = CollectionFS.collectionsRoot(in: assets)
                .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
            try? FileManager.default.removeItem(at: colFolder)
        }
        
        document.wrappedValue.collection.removeValue(forKey: name)
        document.wrappedValue.updatedAt = Date()
        
        // Clear selection
        selectedCollectionName = nil
        selectedItemId = nil
        showInspector = false
    }
    
    /// Updates collection-level images
    func updateCollectionImage(key: String, assetPath: AssetPath?, document: Binding<FolioDocument>) {
        guard let name = selectedCollectionName else { return }
        guard var section = document.wrappedValue.collection[name] else { return }
        
        section.images[key] = assetPath
        document.wrappedValue.collection[name] = section
        document.wrappedValue.updatedAt = Date()
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
    func addItem(document: Binding<FolioDocument>) {
        guard let name = selectedCollectionName else { return }
        guard var section = document.wrappedValue.collection[name] else { return }
        
        // Generate unique label for new item
        let uniqueLabel = generateUniqueItemLabel(existingItems: section.items)
        
        let newItem = JSONCollectionItem(
            label: uniqueLabel,
            order: section.items.count
        )
        
        // Add item
        section.items.append(newItem)
        document.wrappedValue.collection[name] = section
        document.wrappedValue.updatedAt = Date()
        
        // Select and show in inspector
        selectedItemId = newItem.id
        showInspector = true
        
        // Create item folder if assets folder exists
        if let assets = document.wrappedValue.resolvedAssetsFolderURL() {
            let colFolder = CollectionFS.collectionsRoot(in: assets)
                .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
            _ = try? CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: uniqueLabel)
        }
    }
    
    /// Deletes the currently selected item
    func deleteItem(document: Binding<FolioDocument>) {
        guard let name = selectedCollectionName,
              let itemId = selectedItemId else { return }
        guard var section = document.wrappedValue.collection[name] else { return }
        guard let index = section.items.firstIndex(where: { $0.id == itemId }) else { return }
        
        let item = section.items[index]
        
        // Remove item folder from file system if it exists
        if let assets = document.wrappedValue.resolvedAssetsFolderURL() {
            let colFolder = CollectionFS.collectionsRoot(in: assets)
                .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
            let itemFolder = colFolder.appendingPathComponent(CollectionFS.safeName(item.label), isDirectory: true)
            try? FileManager.default.removeItem(at: itemFolder)
        }
        
        // Remove item
        section.items.remove(at: index)
        document.wrappedValue.collection[name] = section
        document.wrappedValue.updatedAt = Date()
        
        // Deselect
        selectedItemId = nil
        showInspector = false
    }
    
    /// Copies a file to the collection's assets folder
    func copyFileToAssets(from sourceURL: URL, document: Binding<FolioDocument>) {
        guard let name = selectedCollectionName,
              let itemId = selectedItemId,
              let assets = document.wrappedValue.resolvedAssetsFolderURL() else { return }
        
        guard var section = document.wrappedValue.collection[name],
              let index = section.items.firstIndex(where: { $0.id == itemId }) else { return }
        
        let itemLabel = section.items[index].label
        let colFolder = CollectionFS.collectionsRoot(in: assets)
            .appendingPathComponent(CollectionFS.safeName(name), isDirectory: true)
        
        do {
            let itemFolder = try CollectionFS.ensureItemFolder(collectionFolder: colFolder, itemLabel: itemLabel)
            let destURL = try CollectionFS.copyWithCollision(from: sourceURL, to: itemFolder)
            
            // Update file path - calculate relative path from assets folder
            let relativePath = destURL.relativePath(from: assets) ?? destURL.lastPathComponent
            section.items[index].filePath = AssetPath(id: UUID(), path: relativePath)
            
            document.wrappedValue.collection[name] = section
            document.wrappedValue.updatedAt = Date()
            
        } catch {
            print("Error copying file to assets: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generates a unique label for a new item in a collection
    private func generateUniqueItemLabel(existingItems: [JSONCollectionItem]) -> String {
        let baseLabel = "New Item"
        let existingLabels = Set(existingItems.map { $0.label })
        
        // If base label is not taken, use it
        if !existingLabels.contains(baseLabel) {
            return baseLabel
        }
        
        // Otherwise, find next available number
        var counter = 2
        while existingLabels.contains("\(baseLabel) \(counter)") {
            counter += 1
        }
        return "\(baseLabel) \(counter)"
    }
    
    /// Validates that a label is unique within the collection (excluding the item being edited)
    func isLabelUnique(_ label: String, excludingItemId: UUID, in collectionName: String, document: FolioDocument) -> Bool {
        guard let section = document.collection[collectionName] else { return true }
        
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return !section.items.contains { item in
            item.id != excludingItemId && item.label == trimmedLabel
        }
    }
}


//
//  Collection.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//  Refactored to use CollectionViewModel on 11/20/25
//


import SwiftUI
import AppKit

struct CollectionTabView: View {
    @Binding var document: FolioDocument
    @EnvironmentObject private var viewModel: CollectionViewModel
    @EnvironmentObject private var inspectorState: InspectorState
    @State private var showDeleteCollectionAlert = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        mainContentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
            // Update viewModel's undoManager reference
            viewModel.undoManager = undoManager
        }
        .alert("Delete collection?", isPresented: $showDeleteCollectionAlert) {
            Button("Delete", role: .destructive) {
                viewModel.deleteCollection(document: $document)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the collection and all of its items.")
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        if let collectionName = viewModel.selectedCollectionName,
           let section = document.collection[collectionName] {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Collection name
                    TextField("Collection Name", text: Binding(
                        get: { collectionName },
                        set: { newName in
                            viewModel.renameCollection(to: newName, document: $document)
                        }
                    ))
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    
                    // Collection Images Section
                    GroupBox("Collection Images") {
                        HStack(spacing: 16) {
                            imageSlotColumn(for: .banner, collectionName: collectionName)
                            imageSlotColumn(for: .thumbnail, collectionName: collectionName)
                            imageSlotColumn(for: .icon, collectionName: collectionName)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    HStack {
                        Button {
                            viewModel.addItem(document: $document)
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            showDeleteCollectionAlert = true
                        } label: {
                            Label("Delete Collection", systemImage: "trash")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Items list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if section.items.isEmpty {
                            Text("No items yet. Click 'Add Item' to get started.")
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 12)
                            ], spacing: 12) {
                                ForEach(section.items) { item in
                                    CollectionItemCard(
                                        item: item,
                                        document: document,
                                        isSelected: viewModel.selectedItemId == item.id,
                                        onSelect: {
                                            viewModel.selectItem(id: item.id)
                                            inspectorState.isVisible = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("No Collection Selected")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Select a collection from the sidebar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private func imageSlotColumn(for label: ImageLabel, collectionName: String) -> some View {
        VStack(spacing: 4) {
            Text(label.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ImageSlotView(
                label: label,
                jsonImage: Binding<AssetPath?>(
                    get: {
                        document.collection[collectionName]?.images[label.storageKey]
                    },
                    set: { newValue in
                        viewModel.updateCollectionImage(key: label.storageKey, assetPath: newValue, document: $document)
                    }
                ),
                document: $document,
                labelPrefix: Binding<String>(
                    get: { collectionName },
                    set: { newValue in
                        viewModel.renameCollection(to: newValue, document: $document)
                    }
                )
            )
            .frame(width: label == .banner ? 200 : 100, 
                   height: label == .banner ? 100 : 100)
        }
    }
}

// MARK: - Collection Item Card

struct CollectionItemCard: View {
    let item: JSONCollectionItem
    let document: FolioDocument
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack {
                    if let url = thumbnailURL(for: item),
                       let image = NSImage(contentsOf: url) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                // Label
                Text(item.label.isEmpty ? "Untitled Item" : item.label)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Type and status
                HStack(spacing: 6) {
                    Image(systemName: iconForType(item.type))
                        .font(.caption)
                    Text(item.type.rawValue)
                        .font(.caption)
                    Spacer()
                    Text(statusText(for: item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func thumbnailURL(for item: JSONCollectionItem) -> URL? {
        // Check new path property first
        if !item.thumbnail.path.isEmpty, let assetsURL = document.assetsFolder?.resolvedURL() {
            return assetsURL.appendingPathComponent(item.thumbnail.path)
        }
        // Fallback to legacy properties
        if let edited = item.thumbnail.pathToEdited, !edited.isEmpty {
            return URL(fileURLWithPath: edited)
        }
        if let original = item.thumbnail.pathToOriginal, !original.isEmpty {
            return URL(fileURLWithPath: original)
        }
        return nil
    }
    
    private func iconForType(_ type: CollectionItemType) -> String {
        switch type {
        case .file: return "doc"
        case .urlLink: return "link"
        case .folio: return "folder"
        }
    }
    
    private func statusText(for item: JSONCollectionItem) -> String {
        switch item.type {
        case .file:
            let hasFile = (item.filePath?.path.isEmpty == false)
                || !(item.filePath?.pathToOriginal ?? "").isEmpty
                || !(item.filePath?.pathToEdited ?? "").isEmpty
            return hasFile ? "✓" : "No file"
        case .urlLink:
            let hasURL = !(item.url ?? "").isEmpty
            return hasURL ? "✓" : "No URL"
        case .folio:
            let hasProject = !(item.url ?? "").isEmpty
            return hasProject ? "✓" : "No project"
        }
    }
}

// MARK: - Legacy Views (Preserved for reference, not used)

/*
struct CollectionDetailView: View {
    @Binding var document: FolioDocument
    @Binding var selectedItem: CollectionTabView.SelectedItem?
    @Binding var errorMessage: String?
    @Binding var showDeleteCollectionAlert: Bool

    let nameBindingProvider: () -> Binding<String>?
    let addItemAction: () -> Void
    let deleteCollectionAction: () -> Void
    let moveItem: (Int, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sel = selectedItem {
                let collectionName = sel.collectionName

                if let nameBinding = nameBindingProvider() {
                    TextField("Collection Name", text: nameBinding)
                        .font(.title3)
                }
                
                // Collection Images Section
                GroupBox("Collection Images") {
                    HStack(spacing: 16) {
                        imageSlotColumn(for: .banner, collectionName: collectionName)
                        imageSlotColumn(for: .thumbnail, collectionName: collectionName)
                        imageSlotColumn(for: .icon, collectionName: collectionName)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Button {
                        addItemAction()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        showDeleteCollectionAlert = true
                        deleteCollectionAction()
                    } label: {
                        Label("Delete Collection", systemImage: "trash")
                    }
                }
                .padding(.bottom, 4)

                List {
                    Section("Items") {
                        let items = document.collection[collectionName]?.items ?? []
                        ForEach(Array(items.enumerated()), id: \.1.id) { index, item in
                            CollectionDetailTile(
                                collectionName: collectionName,
                                index: index,
                                item: item,
                                isSelected: selectedItem?.collectionName == collectionName && selectedItem?.index == index,
                                onSelect: {
                                    selectedItem = .init(collectionName: collectionName, index: index)
                                },
                                onMoveUp: {
                                    if index > 0 {
                                        moveItem(index, index - 1)
                                    }
                                },
                                onMoveDown: {
                                    if index < items.count - 1 {
                                        moveItem(index, index + 1)
                                    }
                                }
                            )
                        }
                        .onMove { from, to in
                            var items = document.collection[collectionName]?.items ?? []
                            items.move(fromOffsets: from, toOffset: to)
                            if var section = document.collection[collectionName] {
                                section.items = items
                                document.collection[collectionName] = section
                            }
                            
                            // Adjust selection if needed
                            if let sel = selectedItem, sel.collectionName == collectionName, let selIndex = sel.index {
                                if let movedIndex = from.first {
                                    if selIndex == movedIndex {
                                        let newIndex = to > movedIndex ? to - 1 : to
                                        selectedItem = .init(collectionName: collectionName, index: newIndex)
                                    }
                                }
                            }
                        }
                        
                        if items.isEmpty {
                            Text("No items yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.inset)
            } else {
                Text("No collection selected")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func imageSlotColumn(for label: ImageLabel, collectionName: String) -> some View {
        VStack(spacing: 4) {
            Text(label.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ImageSlotView(
                label: label,
                jsonImage: Binding<AssetPath?>(
                    get: {
                        document.collection[collectionName]?.images[label.storageKey]
                    },
                    set: { newValue in
                        var section = document.collection[collectionName] ?? CollectionSection()
                        if let value = newValue {
                            section.images[label.storageKey] = value
                        } else {
                            section.images.removeValue(forKey: label.storageKey)
                        }
                        document.collection[collectionName] = section
                    }
                ),
                document: $document,
                labelPrefix: Binding<String>(
                    get: { nameBindingProvider()?.wrappedValue ?? "" },
                    set: { newValue in
                        if let binding = nameBindingProvider() {
                            binding.wrappedValue = newValue
                        }
                    }
                )
            )
            .frame(width: label == .banner ? 200 : 100, 
                   height: label == .banner ? 100 : 100)
        }
    }
}

struct CollectionDetailTile: View {
    let collectionName: String
    let index: Int
    let item: JSONCollectionItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Fixed-size image representation
                ZStack {
                    if let url = CollectionHelpers.thumbnailURL(for: item),
                       let image = NSImage(contentsOf: url) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                            Image(systemName: "photo")
                                .imageScale(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 56, height: 56)
                .clipped()
                .cornerRadius(6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label.isEmpty ? "Untitled Item" : item.label)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Text(CollectionHelpers.typeDescription(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        let type = item.type
                        Text(sourceDescription(for: type, item: item))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private func sourceDescription(for type: CollectionItemType, item: JSONCollectionItem) -> String {
    switch type {
    case .file:
        let hasFile = (item.filePath?.pathToOriginal.isEmpty == false) || (item.filePath?.pathToEdited.isEmpty == false)
        return hasFile ? "File attached" : "No file attached"
    case .urlLink:
        let hasURL = !(item.url ?? "").isEmpty
        return hasURL ? "URL attached" : "No URL attached"
    case .folio:
        let hasProject = !(item.url ?? "").isEmpty
        return hasProject ? "Folio project linked" : "No project linked"
    }
}

private enum CollectionHelpers {
    static func thumbnailURL(for item: JSONCollectionItem) -> URL? {
        // TODO: If there is a shared thumbnail helper elsewhere, reuse it here.
        // For now this returns nil so the placeholder artwork is used.
        return nil
    }

    static func typeDescription(for item: JSONCollectionItem) -> String {
        // TODO: Keep this in sync with the sidebar's type description if needed.
        return "Item"
    }
}
*/

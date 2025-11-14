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

    // Which item is selected in the sidebar
    struct SelectedItem: Hashable {
        var collectionName: String
        /// index == nil means the collection itself (detail view) is selected
        var index: Int?
    }

    @Binding var selectedItem: SelectedItem?
    @State private var errorMessage: String?
    @State private var showDeleteCollectionAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let sel = selectedItem, sel.index == nil {
                // Collection-level detail view
                CollectionDetailView(
                    document: $document,
                    selectedItem: $selectedItem,
                    errorMessage: $errorMessage,
                    showDeleteCollectionAlert: $showDeleteCollectionAlert,
                    nameBindingProvider: { bindingForCollectionName() },
                    addItemAction: { addItemToSelectedCollection() },
                    deleteCollectionAction: { handleDeleteCollectionTapped() },
                    moveItem: { from, to in
                        moveItemWithinCollection(collectionName: sel.collectionName, from: from, to: to)
                    }
                )
            } else if let binding = bindingForSelectedItem(),
                      let sel = selectedItem,
                      let _ = sel.index {
                // Item editor for a specific collection item
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            // Back to collection-level detail
                            selectedItem = .init(collectionName: sel.collectionName, index: nil)
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text(sel.collectionName)
                            .font(.headline)
                    }
                    .padding([.horizontal, .top])

                    CollectionItemEditor(
                        document: $document,
                        item: binding,
                        collectionName: sel.collectionName,
                        assetsFolder: document.assetsFolder?.resolvedURL(),
                        onDelete: { deleteSelectedItem() }
                    )
                    .padding(.top, 4)
                }
            } else {
                Text("Select a collection or item from the sidebar.")
                    .foregroundStyle(.secondary)
                    .padding()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Delete collection?", isPresented: $showDeleteCollectionAlert) {
            Button("Delete", role: .destructive) {
                if let name = selectedItem?.collectionName {
                    deleteCollection(named: name)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the collection and all of its items.")
        }
    }
    private func bindingForCollectionName() -> Binding<String>? {
        guard selectedItem != nil else { return nil }

        return Binding<String>(
            get: {
                selectedItem?.collectionName ?? ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .newlines)
                guard !trimmed.isEmpty else { return }

                guard var currentSel = selectedItem else { return }
                guard trimmed != currentSel.collectionName else { return }

                if document.collection[trimmed] != nil {
                    errorMessage = "A collection with this name already exists."
                    return
                }

                guard let items = document.collection.removeValue(forKey: currentSel.collectionName) else { return }
                document.collection[trimmed] = items
                currentSel.collectionName = trimmed
                selectedItem = currentSel
                errorMessage = nil
            }
        )
    }

    // MARK: - Helpers

    private func bindingForSelectedItem() -> Binding<JSONCollectionItem>? {
        guard let sel = selectedItem,
              let index = sel.index,
              let section = document.collection[sel.collectionName],
              section.items.indices.contains(index)
        else { return nil }

        return Binding<JSONCollectionItem>(
            get: {
                document.collection[sel.collectionName]!.items[index]
            },
            set: { newValue in
                DispatchQueue.main.async {
                    guard var section = document.collection[sel.collectionName] else { return }
                    section.items[index] = newValue
                    document.collection[sel.collectionName] = section
                }
            }
        )
    }

    private func deleteSelectedItem() {
        guard let sel = selectedItem,
              let index = sel.index,
              var section = document.collection[sel.collectionName]
        else { return }

        var items = section.items
        guard items.indices.contains(index) else { return }

        items.remove(at: index)
        section.items = items
        document.collection[sel.collectionName] = section

        // Clear or move selection
        if items.isEmpty {
            selectedItem = nil
        } else {
            let newIndex = min(index, items.count - 1)
            selectedItem = SelectedItem(collectionName: sel.collectionName, index: newIndex)
        }
    }

    private func handleDeleteCollectionTapped() {
        guard let sel = selectedItem else { return }
        let items = document.collection[sel.collectionName]?.items ?? []
        if items.isEmpty {
            deleteCollection(named: sel.collectionName)
        } else {
            showDeleteCollectionAlert = true
        }
    }

    private func deleteCollection(named name: String) {
        document.collection.removeValue(forKey: name)
        selectedItem = nil
        errorMessage = nil
    }

    private func addItemToSelectedCollection() {
        guard let sel = selectedItem else { return }
        var section = document.collection[sel.collectionName] ?? CollectionSection()
        var items = section.items

        // Append a new empty item. Adjust initializer as needed for JSONCollectionItem.
        let newItem = JSONCollectionItem()
        items.append(newItem)

        section.items = items
        document.collection[sel.collectionName] = section
        selectedItem = SelectedItem(collectionName: sel.collectionName, index: items.count - 1)
    }

    private func moveItemWithinCollection(collectionName: String, from sourceIndex: Int, to destinationIndex: Int) {
        guard var section = document.collection[collectionName] else { return }
        var items = section.items
        guard items.indices.contains(sourceIndex),
              items.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }

        let moved = items.remove(at: sourceIndex)
        items.insert(moved, at: destinationIndex)
        section.items = items
        document.collection[collectionName] = section

        // Adjust selection if needed
        if var sel = selectedItem,
           sel.collectionName == collectionName,
           let selIndex = sel.index {

            if selIndex == sourceIndex {
                sel.index = destinationIndex
                selectedItem = sel
            } else if sourceIndex < destinationIndex {
                if selIndex > sourceIndex && selIndex <= destinationIndex {
                    sel.index = selIndex - 1
                    selectedItem = sel
                }
            } else {
                if selIndex >= destinationIndex && selIndex < sourceIndex {
                    sel.index = selIndex + 1
                    selectedItem = sel
                }
            }
        }
    }
}

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

                // Collection banner image stored per collection section
                ImageSlotView(
                    label: .banner,
                    jsonImage: Binding<AssetPath?>(
                        get: {
                            document.collection[collectionName]?.images["banner"]
                        },
                        set: { newValue in
                            var section = document.collection[collectionName] ?? CollectionSection()
                            if let value = newValue {
                                section.images["banner"] = value
                            } else {
                                section.images.removeValue(forKey: "banner")
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
                .frame(minHeight: 80, maxHeight: 180)

                if let nameBinding = nameBindingProvider() {
                    TextField("Collection Name", text: nameBinding)
                        .font(.title3)
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

                ScrollView {
                    let items = document.collection[collectionName]?.items ?? []
                    LazyVStack(alignment: .leading, spacing: 8) {
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
                    }
                    .padding(.top, 8)
                }
            } else {
                Text("No collection selected")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
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

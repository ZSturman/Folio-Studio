//
//  CollectionSectionRow.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//  LEGACY - Replaced by ViewModel architecture on 11/20/25
//

/*
import SwiftUI
import AppKit
import UniformTypeIdentifiers


struct CollectionSectionRow: View {
    let collectionName: String
    @Binding var items: [JSONCollectionItem]
    let onDelete: (JSONCollectionItem) -> Void
    let moveItemUp: (Int) -> Void
    let moveItemDown: (Int) -> Void

    @Binding var selectedItem: CollectionTabView.SelectedItem?
    @State private var draggedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {

                Button {
                    selectedItem = .init(collectionName: collectionName, index: nil)
                } label: {
                    HStack {
                        Text(collectionName)
                            .font(.headline)
                            .fontWeight(.bold) // Make collection names bold
                        Spacer()
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle()) // Make full width tappable
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedItem?.collectionName == collectionName && selectedItem?.index == nil
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )



                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        let isSelected = selectedItem?.collectionName == collectionName &&
                                         selectedItem?.index == index

                        HStack(alignment: .center, spacing: 8) {
                            // Main tappable area (thumbnail + texts)
                            Button {
                                selectedItem = .init(collectionName: collectionName, index: index)
                            } label: {
                                HStack(alignment: .center, spacing: 8) {
                                    // Thumbnail or placeholder
                                    ZStack {
                                        if let url = thumbnailURL(for: item),
                                           let image = NSImage(contentsOf: url) {
                                            Image(nsImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 24, height: 24)
                                                .clipped()
                                                .cornerRadius(3)
                                        } else {
                                            RoundedRectangle(cornerRadius: 4)
                                                .strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
                                            Image(systemName: "photo")
                                                .imageScale(.small)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 24, height: 24)

                                    // Text stack
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.label.isEmpty ? "Item" : item.label)
                                            .lineLimit(1)

                                        Text(typeDescription(for: item))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading, 32) // Increased indentation for hierarchy
                        .padding(.vertical, 2)
                        .listRowBackground(
                            isSelected
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .onDrag {
                            draggedIndex = index
                            return NSItemProvider(object: NSString(string: item.label.isEmpty ? "Item" : item.label))
                        }
                        .onDrop(of: [.text],
                                delegate: CollectionItemDropDelegate(
                                    collectionName: collectionName,
                                    destinationIndex: index,
                                    items: $items,
                                    draggedIndex: $draggedIndex,
                                    selectedItem: $selectedItem
                                )
                        )
                        .contextMenu {
                            Button {
                                if index > 0 {
                                    moveItemUp(index)
                                }
                            } label: {
                                Label("Move Up", systemImage: "chevron.up")
                            }
                            .disabled(index == 0)

                            Button {
                                if index < items.count - 1 {
                                    moveItemDown(index)
                                }
                            } label: {
                                Label("Move Down", systemImage: "chevron.down")
                            }
                            .disabled(index == items.count - 1)

                            Divider()

                            Button(role: .destructive) {
                                onDelete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            
        }
        .padding(.vertical, 2)
    }
}

private func thumbnailURL(for item: JSONCollectionItem) -> URL? {
    let thumb = item.thumbnail
    if !thumb.pathToEdited.isEmpty {
        return URL(fileURLWithPath: thumb.pathToEdited)
    }
    if !thumb.pathToOriginal.isEmpty {
        return URL(fileURLWithPath: thumb.pathToOriginal)
    }
    return nil
}

private func typeDescription(for item: JSONCollectionItem) -> String {
    let typeEnum = item.type
    let prefix = typeEnum.rawValue + ": "

    let value: String?
    switch typeEnum {
    case .file:
        // Use whatever makes sense for your AssetPath to get a filename. Fallback to label.
        value = item.filePath?.pathToEdited ?? (item.label.isEmpty ? nil : item.label)
    case .urlLink:
        value = item.url
    case .folio:
        // For Folio items, use the label as the project name fallback.
        value = item.label.isEmpty ? nil : item.label
    }

    return prefix + (value?.isEmpty == false ? value! : "None")
}

private struct CollectionItemDropDelegate: DropDelegate {
    let collectionName: String
    let destinationIndex: Int
    @Binding var items: [JSONCollectionItem]
    @Binding var draggedIndex: Int?
    @Binding var selectedItem: CollectionTabView.SelectedItem?

    func dropEntered(_ info: DropInfo) {
        guard let from = draggedIndex,
              from != destinationIndex,
              from >= 0,
              from < items.count,
              destinationIndex >= 0,
              destinationIndex < items.count else {
            return
        }

        withAnimation {
            let movedItem = items.remove(at: from)
            let adjustedIndex = destinationIndex > from ? destinationIndex - 1 : destinationIndex
            items.insert(movedItem, at: adjustedIndex)
            draggedIndex = adjustedIndex

            // Update selection indices if needed
            if var sel = selectedItem,
               sel.collectionName == collectionName,
               let selIndex = sel.index {

                if selIndex == from {
                    sel.index = adjustedIndex
                    selectedItem = sel
                } else if from < adjustedIndex {
                    if selIndex > from && selIndex <= adjustedIndex {
                        sel.index = selIndex - 1
                        selectedItem = sel
                    }
                } else {
                    if selIndex >= adjustedIndex && selIndex < from {
                        sel.index = selIndex + 1
                        selectedItem = sel
                    }
                }
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedIndex = nil
        return true
    }

    func dropUpdated(_ info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
*/

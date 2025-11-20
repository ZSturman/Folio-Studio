//
//  CollectionSidebar.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//
//  LEGACY - Replaced by ViewModel architecture on 11/20/25
//  Preserved for reference. Use CollectionSidebarNew.swift instead.
//

/*
import Foundation
import SwiftUI

struct CollectionSidebar: View {
    @Binding var document: FolioDocument
    
    @Binding var selectedItem: CollectionTabView.SelectedItem?

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 8) {

            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }

            Divider()

            List {
                Section {
                    Button {
                        addCollection()
                    } label: {
                        Label("New Collection", systemImage: "plus")
                    }
                }
                
                Section("Collections") {
                    ForEach(sortedCollectionKeys, id: \.self) { key in
                        Button {
                            selectedItem = .init(collectionName: key, index: nil)
                        } label: {
                            HStack {
                                Text(key)
                                Spacer()
                                Text("\(document.collection[key]?.items.count ?? 0)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            selectedItem?.collectionName == key && selectedItem?.index == nil
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                    }
                    
                    if sortedCollectionKeys.isEmpty {
                        Text("No collections yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    private func deleteItem(_ item: JSONCollectionItem, in collectionName: String) {
        guard var section = document.collection[collectionName] else { return }
        guard let index = section.items.firstIndex(where: { $0.id == item.id }) else { return }

        section.items.remove(at: index)

        if section.items.isEmpty {
            // Remove the entire collection if it has no items left
            document.collection.removeValue(forKey: collectionName)

            if let sel = selectedItem, sel.collectionName == collectionName {
                // Select the first item of the first remaining collection, if any
                if let firstName = sortedCollectionKeys.first,
                   let firstSection = document.collection[firstName],
                   !firstSection.items.isEmpty {
                    selectedItem = CollectionTabView.SelectedItem(collectionName: firstName, index: 0)
                } else {
                    selectedItem = nil
                }
            }
            return
        }

        document.collection[collectionName] = section

        // Adjust selection if needed
        if let sel = selectedItem, sel.collectionName == collectionName, let selIndex = sel.index {
            if selIndex == index {
                // Deleted the selected item
                if section.items.isEmpty {
                    selectedItem = nil
                } else {
                    let newIndex = min(index, section.items.count - 1)
                    selectedItem = CollectionTabView.SelectedItem(collectionName: collectionName, index: newIndex)
                }
            } else if selIndex > index {
                // Shift selected index down by one to account for removal before it
                selectedItem = CollectionTabView.SelectedItem(collectionName: collectionName, index: selIndex - 1)
            }
        }
    }


    private var sortedCollectionKeys: [String] {
        document.collection.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Add collection

    private func addCollection() {
        let name = nextDefaultCollectionName()
        let newItem = JSONCollectionItem()
        document.collection[name] = CollectionSection(images: [:], items: [newItem])
        errorMessage = nil
        selectedItem = CollectionTabView.SelectedItem(collectionName: name, index: 0)
    }

    private func nextDefaultCollectionName() -> String {
        let base = "New Collection"
        if document.collection[base] == nil {
            return base
        }
        var index = 2
        while document.collection["\(base) \(index)"] != nil {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func moveItem(in collectionName: String, from sourceIndex: Int, to destinationIndex: Int) {
        guard var section = document.collection[collectionName] else { return }
        var items = section.items
        guard items.indices.contains(sourceIndex),
              items.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }

        let moved = items.remove(at: sourceIndex)
        items.insert(moved, at: destinationIndex)
        section.items = items
        document.collection[collectionName] = section

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


private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
*/

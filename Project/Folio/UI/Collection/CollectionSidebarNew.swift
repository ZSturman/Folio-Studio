//
//  CollectionSidebarNew.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//  Updated to use CollectionViewModel pattern
//

import SwiftUI

struct CollectionSidebarNew: View {
    @Binding var document: FolioDocument
    @ObservedObject var viewModel: CollectionViewModel
    @EnvironmentObject var inspectorState: InspectorState

    var body: some View {
        VStack(spacing: 8) {
            Divider()

            List(selection: Binding(
                get: { viewModel.selectedCollectionName },
                set: { newName in
                    if let name = newName {
                        // Use Task to defer state updates until after view update
                        Task { @MainActor in
                            viewModel.selectedCollectionName = name
                            viewModel.selectedItemId = nil
                            viewModel.showInspector = false
                            inspectorState.collectionSelection = (name, nil)
                        }
                    }
                }
            )) {
                Section {
                    Button {
                        viewModel.createCollection(document: $document)
                    } label: {
                        Label("New Collection", systemImage: "plus")
                    }
                }
                
                Section("Collections") {
                    ForEach(sortedCollectionKeys, id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(document.collection[key]?.items.count ?? 0)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .tag(key)
                        .contentShape(Rectangle())
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

    private var sortedCollectionKeys: [String] {
        document.collection.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

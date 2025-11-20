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

    var body: some View {
        VStack(spacing: 8) {
            Divider()

            List(selection: Binding(
                get: { viewModel.selectedCollectionName },
                set: { newName in
                    if let name = newName {
                        viewModel.selectedCollectionName = name
                        viewModel.selectedItemId = nil
                        viewModel.showInspector = false
                    }
                }
            )) {
                Section {
                    Button {
                        viewModel.createCollection()
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

//
//  ResourcesDetailView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//

import SwiftUI

struct ResourcesDetailView: View {
    @Binding var document: FolioDocument
    @State private var scrollTarget: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if document.resources.isEmpty {
                        VStack(spacing: 8) {
                            Text("No resources yet")
                                .font(.headline)
                            Text("Click the Add Resource button to get started.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(document.resources.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Resource \(index + 1)")
                                        .font(.headline)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Button {
                                            moveResourceUp(from: index)
                                        } label: {
                                            Image(systemName: "arrow.up")
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(index == 0)

                                        Button {
                                            moveResourceDown(from: index)
                                        } label: {
                                            Image(systemName: "arrow.down")
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(index == document.resources.count - 1)
                                    }
                                }

                                ResourcePickerView(resource: $document.resources[index])
                                    .padding(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.separator)
                                    )
                            }
                            .id(index)
                        }
                    }
                }
                .padding()
                .onChange(of: scrollTarget) { _, newTarget in
                    if let target = newTarget {
                        withAnimation {
                            proxy.scrollTo(target, anchor: .center)
                        }
                        scrollTarget = nil
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addResource()
                } label: {
                    Label("Add Resource", systemImage: "plus")
                }
            }
        }
    }
    
    private func addResource() {
        document.resources.append(JSONResource())
        // Scroll to the new resource
        scrollTarget = document.resources.count - 1
    }

    private func moveResourceUp(from index: Int) {
        guard index > 0 else { return }
        let resource = document.resources.remove(at: index)
        document.resources.insert(resource, at: index - 1)
    }

    private func moveResourceDown(from index: Int) {
        guard index < document.resources.count - 1 else { return }
        let resource = document.resources.remove(at: index)
        document.resources.insert(resource, at: index + 1)
    }
}

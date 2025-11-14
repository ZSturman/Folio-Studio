////
////  ResourceCard.swift
////  Folio
////
////  Created by Zachary Sturman on 11/6/25.
////
//
//import Foundation
//import SwiftUI
//
//struct ResourceSecondarySidebar: View {
//
//    @Binding var document: FolioDocument
//    @Binding var selectedResourceIndex: Int?
//
//    var body: some View {
//        VStack {
//            List(selection: $selectedResourceIndex)
//{
//                    ForEach(document.resources.indices, id: \.self) { i in
//                        Text(displayName(for: document.resources[i]))
//                            .tag(i as Int?)
//                    }
//                    .onDelete(perform: delete)
//                    .onMove(perform: move)
//                }
//                .overlay {
//                    if document.resources.isEmpty {
//                        Text("No resources yet")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            HStack(spacing: 8) {
//                Button(action: {
//                    addResource()
//                }) {
//                    Label("Add", systemImage: "plus")
//                }
//                .buttonStyle(.borderless)
//            }
//        }
//        .onAppear {
//            if !document.resources.isEmpty && selectedResourceIndex == nil {
//                selectedResourceIndex = document.resources.indices.first
//            }
//        }
//    }
//
//    private func displayName(for resource: JSONResource) -> String {
//        if !resource.label.isEmpty { return resource.label }
//        if !resource.url.isEmpty { return resource.url }
//        return "New Resource"
//    }
//
//    private func addResource() {
//        let new = JSONResource(label: "", category: "", type: "", url: "")
//        document.resources.append(new)
//        selectedResourceIndex = document.resources.indices.last
//    }
//
//    private func delete(at offsets: IndexSet) {
//        for index in offsets {
//            document.resources.remove(at: index)
//        }
//        if let selected = selectedResourceIndex,
//           !document.resources.indices.contains(selected) {
//            selectedResourceIndex = document.resources.indices.last
//        }
//    }
//
//    private func move(from source: IndexSet, to destination: Int) {
//        document.resources.move(fromOffsets: source, toOffset: destination)
//    }
//}
//
//#Preview {
//    ResourceSecondarySidebar(document: .constant(FolioDocument()), selectedResourceIndex: .constant(nil))
//}

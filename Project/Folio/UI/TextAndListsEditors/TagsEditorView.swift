//
//  TagsEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//


import SwiftUI
import SwiftData

struct TagsEditorView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument
    
    @Query private var projectTags: [ProjectTag]
    
    var allTags: [String] {
        projectTags.map(\.name)
    }

    var body: some View {
        TaxonomyListEditor(title: "Tags", placeholder: "Add tag", items: $document.tags, onDelta: { added, removed in
            Task {
                let r = sdc.enqueueTagChange(added: added, removed: removed, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[TagsEditorView] enqueueTagChange error: \(e)") }
            }
        }, catalog: allTags)

    }
}

//
//  TopicsEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//


import SwiftUI
import SwiftData

struct TopicsEditorView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument
    
    @Query private var projectTopics: [ProjectTopic]
    
    var allTopics: [String] {
        projectTopics.map(\.name)
    }


    var body: some View {
        TaxonomyListEditor(title: "Topics", placeholder: "Add topic", items: $document.topics, onDelta: { added, removed in
            Task {
                let r = sdc.enqueueTopicsChange(added: added, removed: removed, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[TopicsEditorView] enqueueTopicsChange error: \(e)") }
            }
        }, catalog: allTopics)
    }
}

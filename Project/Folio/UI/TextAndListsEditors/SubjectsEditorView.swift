//
//  SubjectsEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//


import SwiftUI
import SwiftData

struct SubjectsEditorView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument
    
    @Query private var projectSubjects: [ProjectSubject]
    
    var allSubjects: [String] {
        projectSubjects.map(\.name)
    }

    var body: some View {
        TaxonomyListEditor(title: "Subjects", placeholder: "Add subject", items: $document.subjects,  onDelta: { added, removed in
            Task {
                let r = sdc.enqueueSubjectsChange(added: added, removed: removed, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[SubjectsEditorView] enqueueSubjectsChange error: \(e)") }
            }
        }, catalog: allSubjects)
    }
}

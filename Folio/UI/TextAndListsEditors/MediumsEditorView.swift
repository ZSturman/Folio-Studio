//
//  MediumsEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//


import SwiftUI
import SwiftData

struct MediumsEditorView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument
    
    @Query private var projectMediums: [ProjectMedium]
    
    var allMediums: [String] {
        projectMediums.map(\.name)
    }

    var body: some View {
        TaxonomyListEditor(title: "Mediums", placeholder: "Add medium", items: $document.mediums, onDelta: { added, removed in
            Task {
                let r = sdc.enqueueMediumsChange(added: added, removed: removed, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[MediumsEditorView] enqueueMediumsChange error: \(e)") }
            }
        }, catalog: allMediums)
    }
}

//
//  GenresEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//


import SwiftUI
import SwiftData

struct GenresEditorView: View {
    @Environment(\.modelContext) private var context: ModelContext
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument
    
    @Query private var genres: [ProjectGenre]
    
    var allGenres: [String] {
        genres.map(\.name)
    }

    var body: some View {
        TaxonomyListEditor(title: "Genres", placeholder: "Add genre", items: $document.genres, onDelta: { added, removed in
            Task {
                let r = sdc.enqueueGenresChange(added: added, removed: removed, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[GenresEditorView] enqueueGenresChange error: \(e)") }
            }
        }, catalog: allGenres)
    }
}

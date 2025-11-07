//
//  TagsAndClassification.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import Foundation
import SwiftUI

struct TagsAndClassificationTabView: View {
    @Binding var document: FolioDocument

    var body: some View {
        VStack(spacing: 10) {
            TagsEditorView(document: $document)
            TopicsEditorView(document: $document)
            SubjectsEditorView(document: $document)
            GenresEditorView(document: $document)
            MediumsEditorView(document: $document)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        TagsAndClassificationTabView(document: .constant(FolioDocument()))
    }
}

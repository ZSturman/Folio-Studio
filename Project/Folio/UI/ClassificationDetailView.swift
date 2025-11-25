//
//  ClassificationDetailView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/25/25.
//

import SwiftUI

struct ClassificationDetailView: View {
    @Binding var document: FolioDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Domain & Category")
                        .font(.subheadline)
                        .bold()
                    DomainCategoryPickerView(document: $document)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Status")
                        .font(.subheadline)
                        .bold()
                    ProjectStatusPickerView(document: $document)
                }
                    
            }
            Divider()
            TagsEditorView(document: $document)
            TopicsEditorView(document: $document)
            SubjectsEditorView(document: $document)
            GenresEditorView(document: $document)
            MediumsEditorView(document: $document)
        }
    }
}

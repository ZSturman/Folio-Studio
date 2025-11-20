//
//  BasicInfoClassificationView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//

import Foundation
import SwiftUI

struct BasicInfoClassificationView: View {
    @Binding var document: FolioDocument
    
    var body: some View {
        Form {
            Section("Domain & Category") {
                DomainCategoryPickerView(document: $document)
            }
            
            Section("Project Status") {
                ProjectStatusPickerView(document: $document)
            }
            
            Section("Tags") {
                TagsEditorView(document: $document)
            }
            
            Section("Topics") {
                TopicsEditorView(document: $document)
            }
            
            Section("Subjects") {
                SubjectsEditorView(document: $document)
            }
            
            Section("Genres") {
                GenresEditorView(document: $document)
            }
            
            Section("Mediums") {
                MediumsEditorView(document: $document)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}


struct ContentSummaryView: View {
    @Binding var document: FolioDocument
    
    var body: some View {
        Text("")
    }
}


struct ContentDescriptionView: View {
    @Binding var document: FolioDocument
    
    var body: some View {
        Text("")
    }
}


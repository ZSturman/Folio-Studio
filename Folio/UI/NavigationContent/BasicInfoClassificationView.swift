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
    
    @State private var showTopics: Bool = false
    @State private var showSubjects: Bool = false
    @State private var showGenres: Bool = false
    @State private var showMediums: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            
            DomainCategoryPickerView(document: $document)
            ProjectStatusPickerView(document: $document)
            
            
            TagsEditorView(document: $document)
            

            if showTopics {
                TopicsEditorView(document: $document)
            }
            if showSubjects {
                SubjectsEditorView(document: $document)
            }
            if showGenres {
                GenresEditorView(document: $document)
            }
            if showMediums {
                MediumsEditorView(document: $document)
            }
            
            Menu("Add classification…") {
                Toggle("Topics", isOn: $showTopics)
                Toggle("Subjects", isOn: $showSubjects)
                Toggle("Genres", isOn: $showGenres)
                Toggle("Mediums", isOn: $showMediums)
            }
        }
        .onAppear {
            showTopics = !document.topics.isEmpty
            showSubjects = !document.subjects.isEmpty
            showGenres = !document.genres.isEmpty
            showMediums = !document.mediums.isEmpty
        }
       
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


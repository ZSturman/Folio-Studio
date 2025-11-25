//
//  BasicInfo.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import Foundation
import SwiftUI
import SwiftData




struct BasicInfoTabView: View {
    @Binding var document: FolioDocument
    

    // Computed bindings for optionals and enum mapping
    private var subtitleBinding: Binding<String> {
        Binding(
            get: { document.subtitle },
            set: { document.subtitle = $0.isEmpty ? "" : $0 }
        )
    }
    
    private var summaryBinding: Binding<String> {
        Binding(
            get: { document.summary },
            set: { document.summary = $0.isEmpty ? "" : $0 }
        )
    }
    
    private var featuredBinding: Binding<Bool> {
        Binding(
            get: { document.featured },
            set: { document.featured = $0 }
        )
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                
                VStack {
                    ImageSlotView(
                        label: .thumbnail,
                        jsonImage: Binding(
                            get: { document.images[.thumbnail] },
                            set: { document.images[.thumbnail] = $0 }
                        ),
                        document: $document,
                        labelPrefix: Binding<String>(
                            get: { document.title },
                            set: { document.title = $0 }
                        )
                    )
                    .frame(minWidth: 50, idealWidth: 150, maxWidth: 200)
                }
            
                
                VStack {
                    
                    TitleEditorView(document: $document)
                    VStack(alignment: .leading, spacing: 6) {
                        
                        TextField("Subtitle", text: subtitleBinding)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .padding(.vertical, 4)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.quaternary)
                            }
                    }
                    
                    HStack(alignment: .top, spacing: 32) {
                        Toggle("Featured", isOn: featuredBinding)
                        
                        PrivacyToggle(document: $document)
                        Spacer()
                    }
                    
                    HStack(alignment: .top, spacing: 32) {
                        DocumentCalendarPicker(
                            document: $document,
                            title: "Created At",
                            keyPath: \.createdAt
                        )
                        
                        DocumentCalendarPicker(
                            document: $document,
                            title: "Updated At",
                            keyPath: \.updatedAt
                        )
                        Spacer()
                    }
                    Spacer()
                }
                
            }
            

                
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Summary")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        if summaryBinding.wrappedValue.isEmpty {
                            Text("Write a short overview of this project...")
                                .foregroundStyle(.secondary)
                                .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
                        }
                        
                        TextEditor(text: summaryBinding)
                            .frame(minHeight: 140)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.quaternary)
                    )
                }
            
            
        }

        .padding()
        .navigationTitle("Basic Info")
    }
}

#Preview {
    ScrollView {
        BasicInfoTabView(document: .constant(FolioDocument()))
    }
    
}

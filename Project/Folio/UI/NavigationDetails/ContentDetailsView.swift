//
//  ContentDetailsView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/25/25.
//

import Foundation
import SwiftUI

struct ContentDetailsView: View {
    @Binding var document: FolioDocument
    
    private var summaryBinding: Binding<String> {
        Binding(
            get: { document.summary },
            set: { document.summary = $0.isEmpty ? "" : $0 }
        )
    }
    
    private var descriptionBinding: Binding<String> {
        Binding(
            get: { document.description ?? "" },
            set: { document.description = $0.isEmpty ? "" : $0 }
        )
    }
    
    private var storyBinding: Binding<String> {
        Binding(
            get: { document.story ?? "" },
            set: { document.story = $0.isEmpty ? "" : $0 }
        )
    }
    
    var body: some View {
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
                
                LinedTextEditor(text: summaryBinding, fontSize: 16, lineSpacing: 4)
                    .frame(minHeight: 140)
                    .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )
        }
        
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ZStack(alignment: .topLeading) {
                if descriptionBinding.wrappedValue.isEmpty {
                    Text("Write the description of this project...")
                        .foregroundStyle(.secondary)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
                }
                
                LinedTextEditor(text: descriptionBinding, fontSize: 16, lineSpacing: 4)
                    .frame(minHeight: 140)
                    .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )
        }
        
        VStack(alignment: .leading, spacing: 6) {
            Text("Story")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ZStack(alignment: .topLeading) {
                if storyBinding.wrappedValue.isEmpty {
                    Text("The story associated with this project...")
                        .foregroundStyle(.secondary)
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 0))
                }
                
                LinedTextEditor(text: storyBinding, fontSize: 16, lineSpacing: 4)
                    .frame(minHeight: 140)
                    .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )
        }
        
        Divider()
        CustomDetailsView(document: $document)
    }
    

}

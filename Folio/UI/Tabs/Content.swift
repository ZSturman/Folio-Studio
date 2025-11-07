//
//  Content.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import Foundation
import SwiftUI

struct ContentTabView: View {
    @Binding var document: FolioDocument

    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Story")
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { document.story ?? "" },
                    set: { document.story = $0 }
                ))
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25))
                    )
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { document.description ?? "" },
                    set: { document.description = $0 }
                ))
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25))
                    )
            }
            
            Section {
                ResourceCard(document: $document)
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
  
        ContentTabView(document:
            .constant(FolioDocument()))
    
}

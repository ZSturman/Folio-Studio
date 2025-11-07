//
//  ResourceCard.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//

import Foundation
import SwiftUI

struct ResourceCard: View {
    
    @Binding var document: FolioDocument
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if document.resources.isEmpty {
                Text("No resources yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(document.resources.indices, id: \.self) { i in
                    HStack(alignment: .top) {
                        ResourcePickerView(resource: $document.resources[i])
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button(role: .destructive) {
                            document.resources.remove(at: i)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 8)
                    }
                }
            }
            Button("Add Resource") {
                document.resources.append(JSONResource(
                    label: "", category: "", type: "", url: ""
                ))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }
}

#Preview {
    ResourceCard(document: .constant( FolioDocument()))
}

//
//  SummaryAndDescriptionTextEditor.swift
//  Folio
//
//  Created by Zachary Sturman on 11/10/25.
//

import Foundation
import SwiftUI

struct DocumentTextSection: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextEditor(text: $text)
                .frame(minHeight: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25))
                )
        }
    }
}


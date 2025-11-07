//
//  RawJSONEditor.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI

struct RawJSONEditor: View {
    let title: String
    @Binding var text: String

    init(title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        }
        .padding(.vertical, 4)
    }
}

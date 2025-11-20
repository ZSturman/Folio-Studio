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
    @State private var internalText: String

    init(title: String, text: Binding<String>) {
        self.title = title
        self._text = text
        self._internalText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $internalText)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        }
        .onChange(of: internalText) { _, newValue in
            text = newValue
        }
        .onChange(of: text) { _, newValue in
            if newValue != internalText {
                internalText = newValue
            }
        }
        .padding(.vertical, 4)
    }
}

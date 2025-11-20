//
//  TitleEditorView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//

import SwiftUI

// MARK: - Single-value editors

struct TitleEditorView: View {
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            TextField("Title", text: $document.title)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.quaternary)
                }
        }
        .onChange(of: document.title) { _, newTitle in
            Task {
                let r = sdc.enqueueTitleChange(newTitle, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[BasicInfoTabView] enqueueTitleChange error: \(e)") }
            }
        }
    }
}

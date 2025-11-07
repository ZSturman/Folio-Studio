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
        TextField("Title", text: $document.title)
            .submitLabel(.done)
            .textFieldStyle(.roundedBorder)
            .onChange(of: document.title) { _, newTitle in
                Task {
                    let r = sdc.enqueueTitleChange(newTitle, for: $document.wrappedValue.id)
                    if case .failure(let e) = r { print("[BasicInfoTabView] enqueueTitleChange error: \(e)") }
                }
            }
    }
}

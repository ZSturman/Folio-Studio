//
//  PrivacyToggle.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//

import SwiftUI

struct PrivacyToggle: View {
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Binding var document: FolioDocument

    var body: some View {
        Toggle(isOn: $document.isPublic) {
            HStack(spacing: 8) {
                Image(systemName: document.isPublic ? "globe" : "lock.fill")
                Text("Public")
            }
        }
        #if os(macOS)
        .toggleStyle(.checkbox)
        #endif
        .onChange(of: document.isPublic) { _, isPublic in
            Task {
                let r = sdc.enqueueIsPublicChange(isPublic, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[BasicInfoTabView] enqueueTitleChange error: \(e)") }
            }
        }
    }
}

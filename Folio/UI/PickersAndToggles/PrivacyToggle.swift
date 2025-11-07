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
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                document.isPublic.toggle()
            }
        }) {
            HStack {
                // Icons
                Image(systemName: "lock.fill")
                    .foregroundColor(document.isPublic ? .gray : .white)
                    .opacity(document.isPublic ? 1 : 0.5)
                Spacer()
                Image(systemName: "globe")
                    .foregroundColor(document.isPublic ? .gray : .white)
                    .opacity(document.isPublic ? 0.5 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack(alignment: document.isPublic ?  .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.2))
                    Circle()
                        .fill(document.isPublic ? Color.green : Color.blue )
                        .frame(width: 30, height: 30)
                        .padding(3)
                }
            )
            .frame(width: 100, height: 40)
        }
        .accessibilityLabel(document.isPublic ? "Public" : "Private" )
        .onChange(of: document.isPublic) { _, isPublic in
            Task {
                let r = sdc.enqueueIsPublicChange(isPublic, for: $document.wrappedValue.id)
                if case .failure(let e) = r { print("[BasicInfoTabView] enqueueTitleChange error: \(e)") }
            }
        }
    }
}

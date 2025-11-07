//
//  PermissionRequiredRow.swift
//  Folio
//
//  Created by Zachary Sturman on 11/7/25.
//

import SwiftUI

/// Reusable UI row to indicate permission is required and let the user grant it
struct PermissionRequiredRow: View {
    let title: String
    let url: URL
    var onGranted: (URL) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title) requires permission")
                    .font(.callout).bold()
                    .lineLimit(1)
                Text(url.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Grant Access") {
                if let granted = PermissionHelper.requestAccess(for: url) {
                    onGranted(granted)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.yellow.opacity(0.6))
        )
    }
}

//
//  DatePicker.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//

import Foundation
import SwiftUI


struct DocumentCalendarPicker: View {
    @Binding var document: FolioDocument
    let title: String
    let keyPath: WritableKeyPath<FolioDocument, Date?>

    // Use a non-optional binding for DatePicker while preserving the optional model value
    private var dateBinding: Binding<Date> {
        Binding<Date>(
            get: { document[keyPath: keyPath] ?? Date() },
            set: { document[keyPath: keyPath] = $0 }
        )
    }

    private var hasDate: Bool { document[keyPath: keyPath] != nil }

    private var accessibilityValue: String {
        let date = document[keyPath: keyPath] ?? Date()
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                DatePicker(
                    "",
                    selection: dateBinding,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(accessibilityValue))
            }
        }
        .controlSize(.regular)
        .padding(.vertical, 4)
    }
}

#Preview {
    Form {
        DocumentCalendarPicker(document: .constant(FolioDocument()), title: "Created At", keyPath: \.createdAt)
    }
    .frame(width: 360)
    .padding()
}

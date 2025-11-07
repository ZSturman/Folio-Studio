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
        // Standard macOS layout: a label at leading with the control at trailing
        LabeledContent(title) {
            HStack(spacing: 8) {
                DatePicker(
                    "",
                    selection: dateBinding,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                // Field style is the macOS-standard inline text field with a calendar popover
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

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
        if let date = document[keyPath: keyPath] {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return "None"
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
                .disabled(!hasDate)

                Spacer(minLength: 8)

                if hasDate {
                    Button("Clear") {
                        document[keyPath: keyPath] = nil
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Clear \(title) date"))
                } else {
                    Button("Set") {
                        document[keyPath: keyPath] = Date()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Set \(title) date"))
                }
            }
        }
        .controlSize(.regular)
        .padding(.vertical, 4)
    }
}


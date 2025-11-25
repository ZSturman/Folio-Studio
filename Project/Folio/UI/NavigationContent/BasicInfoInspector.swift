//
//  BasicInfoInspector.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI

/// Inspector panel for Basic Info tab - consolidates Classification and Details
struct CustomDetailsView: View {
    @Binding var document: FolioDocument
    @AppStorage("customFields") private var customFieldsData: Data = Data()
    @State private var customFields: [CustomFieldDefinition] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                detailsSection
            }
            .padding()
        }
        .onAppear {
            loadCustomFields()
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Details")
                .font(.headline)
            
            Text("Details are stored in document.details[] as key-value pairs.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if document.details.isEmpty {
                Text("No custom details")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach($document.details) { $detail in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(detail.key)
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            Button(role: .destructive) {
                                deleteDetail(detail)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        TextField("Key", text: $detail.key)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        
                        detailValueEditor(for: $detail.value)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            }
            
            Button {
                addNewDetail()
            } label: {
                Label("Add Detail", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Detail Value Editor
    
    @ViewBuilder
    private func detailValueEditor(for value: Binding<JSONValue>) -> some View {
        switch value.wrappedValue {
        case .string(let str):
            TextField("Value", text: Binding(
                get: { str },
                set: { value.wrappedValue = .string($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            
        case .number(let num):
            TextField("Value", value: Binding(
                get: { num },
                set: { value.wrappedValue = .number($0) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            
        case .bool(let flag):
            Toggle("Value", isOn: Binding(
                get: { flag },
                set: { value.wrappedValue = .bool($0) }
            ))
            .font(.caption)
            
        default:
            Text("Complex type - edit in Details view")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func deleteDetail(_ detail: DetailItem) {
        document.details.removeAll { $0.id == detail.id }
    }
    
    private func addNewDetail() {
        let newDetail = DetailItem(
            key: "New Detail",
            value: .string("")
        )
        document.details.append(newDetail)
    }
    
    private func loadCustomFields() {
        if let decoded = try? JSONDecoder().decode([CustomFieldDefinition].self, from: customFieldsData) {
            customFields = decoded
        }
    }
}

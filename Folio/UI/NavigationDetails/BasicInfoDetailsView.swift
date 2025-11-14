//
//  OtherFolioFieldsView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import Foundation
import SwiftUI


struct BasicInfoDetailsView: View {
    @Binding var document: FolioDocument
    @State private var newDetailKey: String = ""
    @State private var newFieldKey: String = ""

    @State private var newDetailType: JSONType = .string
    @State private var newDetailString: String = ""
    @State private var newDetailNumber: Double = 0
    @State private var newDetailBool: Bool = false
    @State private var newDetailJSONText: String = ""

    @State private var newFieldType: JSONType = .string
    @State private var newFieldString: String = ""
    @State private var newFieldNumber: Double = 0
    @State private var newFieldBool: Bool = false
    @State private var newFieldJSONText: String = ""

    var body: some View {
        Form {

            Section("Details") {
                if document.details.isEmpty {
                    Text("No details")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($document.details) { $detail in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Key", text: $detail.key)
                                Spacer()
                                typeMenu(for: $detail.value)
                            }
                            valueEditor(for: $detail.value, label: "Value")
                        }
                        .padding(.vertical, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("New detail key", text: $newDetailKey)
                        Spacer()
                        Menu(typeLabel(newDetailType)) {
                            ForEach(JSONType.allCases, id: \.self) { t in
                                Button(typeLabel(t)) { newDetailType = t }
                            }
                        }
                    }
                    Group {
                        switch newDetailType {
                        case .string:
                            TextField("New value", text: $newDetailString)
                        case .number:
                            TextField("New value", value: $newDetailNumber, format: .number)

                        case .bool:
                            Toggle("New value", isOn: $newDetailBool)
                        case .array, .object, .null:
                            RawJSONEditor(
                                title: "New value JSON",
                                text: $newDetailJSONText
                            )
                        }
                    }
                    Button {
                        let trimmed = newDetailKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let newValue: JSONValue
                        switch newDetailType {
                        case .string:
                            newValue = .string(newDetailString)
                        case .number:
                            newValue = .number(newDetailNumber)
                        case .bool:
                            newValue = .bool(newDetailBool)
                        case .array:
                            if let parsed = JSONValue.parseJSONString(newDetailJSONText), case .array = parsed {
                                newValue = parsed
                            } else {
                                newValue = .array([])
                            }
                        case .object:
                            if let parsed = JSONValue.parseJSONString(newDetailJSONText), case .object = parsed {
                                newValue = parsed
                            } else {
                                newValue = .object([:])
                            }
                        case .null:
                            newValue = .null
                        }
                        document.details.append(DetailItem(id: UUID(), key: trimmed, value: newValue))
                        // reset
                        newDetailKey = ""
                        newDetailType = .string
                        newDetailString = ""
                        newDetailNumber = 0
                        newDetailBool = false
                        newDetailJSONText = ""
                    } label: {
                        Label("Add detail", systemImage: "plus")
                    }
                }
            }

            // MARK: Everything else from `values`, type-driven
            Section("Other fields") {
                let otherKeys = document.values.keys
                    .sorted()

                if otherKeys.isEmpty {
                    Text("No additional fields").foregroundStyle(.secondary)
                } else {
                    ForEach(otherKeys, id: \.self) { key in
                        rowForKey(key)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("New field key", text: $newFieldKey)
                        Spacer()
                        Menu(typeLabel(newFieldType)) {
                            ForEach(JSONType.allCases, id: \.self) { t in
                                Button(typeLabel(t)) { newFieldType = t }
                            }
                        }
                    }
                    Group {
                        switch newFieldType {
                        case .string:
                            TextField("New value", text: $newFieldString)
                        case .number:
                            TextField("New value", value: $newFieldNumber, format: .number)
                            #if iOS
                            .keyboardType(.decimalPad)
                            #endif
                        case .bool:
                            Toggle("New value", isOn: $newFieldBool)
                        case .array, .object, .null:
                            RawJSONEditor(
                                title: "New value JSON",
                                text: $newFieldJSONText
                            )
                        }
                    }
                    Button {
                        let trimmed = newFieldKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let newValue: JSONValue
                        switch newFieldType {
                        case .string:
                            newValue = .string(newFieldString)
                        case .number:
                            newValue = .number(newFieldNumber)
                        case .bool:
                            newValue = .bool(newFieldBool)
                        case .array:
                            if let parsed = JSONValue.parseJSONString(newFieldJSONText), case .array = parsed {
                                newValue = parsed
                            } else {
                                newValue = .array([])
                            }
                        case .object:
                            if let parsed = JSONValue.parseJSONString(newFieldJSONText), case .object = parsed {
                                newValue = parsed
                            } else {
                                newValue = .object([:])
                            }
                        case .null:
                            newValue = .null
                        }
                        document.values[trimmed] = newValue
                        // reset
                        newFieldKey = ""
                        newFieldType = .string
                        newFieldString = ""
                        newFieldNumber = 0
                        newFieldBool = false
                        newFieldJSONText = ""
                    } label: {
                        Label("Add field", systemImage: "plus")
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Helpers for editing JSONValue directly
    private enum JSONType: CaseIterable {
        case string, number, bool, array, object, null
    }

    private func typeLabel(_ t: JSONType) -> String {
        switch t {
        case .string: return "String"
        case .number: return "Number"
        case .bool:   return "Bool"
        case .array:  return "Array"
        case .object: return "Object"
        case .null:   return "Null"
        }
    }

    private func jsonType(for value: JSONValue) -> JSONType {
        switch value {
        case .string: return .string
        case .number: return .number
        case .bool:   return .bool
        case .array:  return .array
        case .object: return .object
        case .null:   return .null
        }
    }

    private func bindingValue(_ key: String) -> Binding<JSONValue> {
        Binding<JSONValue>(
            get: { document.values[key] ?? .null },
            set: { document.values[key] = $0 }
        )
    }

    private func bindingText(for value: Binding<JSONValue>) -> Binding<String> {
        Binding<String>(
            get: { value.wrappedValue.string ?? "" },
            set: { value.wrappedValue = .string($0) }
        )
    }

    private func bindingNumber(for value: Binding<JSONValue>) -> Binding<Double> {
        Binding<Double>(
            get: { value.wrappedValue.number ?? 0 },
            set: { value.wrappedValue = .number($0) }
        )
    }

    private func bindingBool(for value: Binding<JSONValue>) -> Binding<Bool> {
        Binding<Bool>(
            get: { value.wrappedValue.bool ?? false },
            set: { value.wrappedValue = .bool($0) }
        )
    }

    @ViewBuilder
    private func typeMenu(for value: Binding<JSONValue>) -> some View {
        Menu(typeLabel(jsonType(for: value.wrappedValue))) {
            Button("String") { value.wrappedValue = .string(value.wrappedValue.string ?? "") }
            Button("Number") { value.wrappedValue = .number(value.wrappedValue.number ?? 0) }
            Button("Bool")   { value.wrappedValue = .bool(value.wrappedValue.bool ?? false) }
            Button("Array")  { value.wrappedValue = .array([]) }
            Button("Object") { value.wrappedValue = .object([:]) }
            Button("Null")   { value.wrappedValue = .null }
        }
    }

    @ViewBuilder
    private func valueEditor(for value: Binding<JSONValue>, label: String) -> some View {
        switch value.wrappedValue {
        case .string:
            TextField(label, text: bindingText(for: value))
        case .number:
            HStack {
                Text(label)
                TextField("", value: bindingNumber(for: value), format: .number)

            }
        case .bool:
            Toggle(label, isOn: bindingBool(for: value))
        case .array:
            DisclosureGroup(label) {
                RawJSONEditor(title: "Array JSON", text: bindingJSON(for: value))
            }
        case .object:
            DisclosureGroup(label) {
                RawJSONEditor(title: "Object JSON", text: bindingJSON(for: value))
            }
        case .null:
            HStack {
                Text("\(label) = null").foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Generic row builder for unknown keys (exhaustive)
    @ViewBuilder
    private func rowForKey(_ key: String) -> some View {
        if let _ = document.values[key] {
            let valueBinding = bindingValue(key)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(key)
                    Spacer()
                    typeMenu(for: valueBinding)
                }
                valueEditor(for: valueBinding, label: key)
            }
            .padding(.vertical, 4)
        } else {
            HStack {
                Text(key)
                Spacer()
                Text("Not set").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bindings for primitives
    private func bindingText(_ key: String) -> Binding<String> {
        Binding(
            get: { document.values[key]?.string ?? "" },
            set: { document.values[key] = .string($0) }
        )
    }

    private func bindingNumber(_ key: String) -> Binding<Double> {
        Binding(
            get: { document.values[key]?.number ?? 0 },
            set: { document.values[key] = .number($0) }
        )
    }

    private func bindingBool(_ key: String) -> Binding<Bool> {
        Binding(
            get: { document.values[key]?.bool ?? false },
            set: { document.values[key] = .bool($0) }
        )
    }

    // MARK: - Raw JSON binding for arrays/objects/null
    // Pretty-prints JSONValue and parses on change.
    private func bindingJSONRaw(_ key: String) -> Binding<String> {
        Binding(
            get: {
                guard let v = document.values[key] else { return "null" }
                return v.prettyPrintedJSONString()
            },
            set: { newString in
                if let parsed = JSONValue.parseJSONString(newString) {
                    document.values[key] = parsed
                }
                // If parse fails, ignore to avoid destroying data.
            }
        )
    }
    private func bindingJSON(for value: Binding<JSONValue>) -> Binding<String> {
        Binding<String>(
            get: {
                value.wrappedValue.prettyPrintedJSONString()
            },
            set: { newString in
                if let parsed = JSONValue.parseJSONString(newString) {
                    value.wrappedValue = parsed
                }
            }
        )
    }
}


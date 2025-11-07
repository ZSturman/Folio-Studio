//
//  Other.swift
//  Folio
//
//  Created by Zachary Sturman on 11/2/25.
//

import Foundation
import SwiftUI






import SwiftUI

struct OtherTabView: View {
    @Binding var document: FolioDocument

    var body: some View {
        Form {
            // MARK: Document fields (known keys on the document itself)
            Section("Document") {
                HStack {
                    Text("ID")
                    Spacer()
                    Text(document.id.uuidString)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                TextField("Title", text: $document.title)
            
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
            }
        }
        .padding()
    }

    // MARK: - Generic row builder for unknown keys (exhaustive)
    @ViewBuilder
    private func rowForKey(_ key: String) -> some View {
        switch document.values[key] {
        case .some(.string):
            TextField(key, text: bindingText(key))

        case .some(.number):
            HStack {
                Text(key)
                TextField("", value: bindingNumber(key), format: .number)
                #if iOS
                    .keyboardType(.decimalPad)
                #endif
            }

        case .some(.bool):
            Toggle(key, isOn: bindingBool(key))

        case .some(.array):
            // Raw JSON editor for arrays
            DisclosureGroup(key) {
                RawJSONEditor(title: "Array JSON", text: bindingJSONRaw(key))
            }

        case .some(.object):
            // Raw JSON editor for objects
            DisclosureGroup(key) {
                RawJSONEditor(title: "Object JSON", text: bindingJSONRaw(key))
            }

        case .some(.null):
            HStack {
                Text("\(key) = null").foregroundStyle(.secondary)
                Spacer()
                Menu("Set…") {
                    Button("String") { document.values[key] = .string("") }
                    Button("Number") { document.values[key] = .number(0) }
                    Button("Bool")   { document.values[key] = .bool(false) }
                    Button("Array")  { document.values[key] = .array([]) }
                    Button("Object") { document.values[key] = .object([:]) }
                }
            }

        case .none:
            // Key not present: show add button
            HStack {
                Text(key)
                Spacer()
                Menu("Add") {
                    Button("String") { document.values[key] = .string("") }
                    Button("Number") { document.values[key] = .number(0) }
                    Button("Bool")   { document.values[key] = .bool(false) }
                    Button("Array")  { document.values[key] = .array([]) }
                    Button("Object") { document.values[key] = .object([:]) }
                    Button("Null")   { document.values[key] = .null }
                }
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
}

#Preview {
    NavigationStack {
        OtherTabView(document: .constant(FolioDocument()))
    }
}

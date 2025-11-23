//
//  JSONTreeView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/23/25.
//

import SwiftUI

struct JSONTreeView: View {
    let data: Data
    
    var body: some View {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            ScrollView {
                VStack(alignment: .leading) {
                    JSONNodeView(key: "Document", value: json, isRoot: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Invalid JSON Data")
                .foregroundStyle(.red)
                .padding()
        }
    }
}

struct JSONNodeView: View {
    let key: String
    let value: Any
    var isRoot: Bool = false
    
    @State private var isExpanded: Bool = false
    
    init(key: String, value: Any, isRoot: Bool = false) {
        self.key = key
        self.value = value
        self.isRoot = isRoot
        // Auto-expand root
        _isExpanded = State(initialValue: isRoot)
    }
    
    var body: some View {
        if let dict = value as? [String: Any] {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(dict.keys.sorted(), id: \.self) { k in
                    JSONNodeView(key: k, value: dict[k]!)
                        .padding(.leading, 16)
                }
            } label: {
                HStack {
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .foregroundStyle(.primary)
                    Text("{ }")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } else if let array = value as? [Any] {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(array.indices, id: \.self) { index in
                    JSONNodeView(key: "[\(index)]", value: array[index])
                        .padding(.leading, 16)
                }
            } label: {
                HStack {
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .bold()
                        .foregroundStyle(.primary)
                    Text("[\(array.count)]")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(alignment: .top) {
                Text(key + ":")
                    .font(.system(.body, design: .monospaced))
                    .bold()
                    .foregroundStyle(.primary)
                
                Text("\(String(describing: value))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 1)
        }
    }
}

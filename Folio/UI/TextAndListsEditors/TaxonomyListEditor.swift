//
//  TaxonomyListEditor.swift
//  Folio
//
//  Created by Zachary Sturman on 11/6/25.
//

import Foundation
import SwiftUI


// MARK: - Reusable list editor

private func delta(old: [String], new: [String]) -> (added: [String], removed: [String]) {
    let o = Set(old.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    let n = Set(new.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    let added = Array(n.subtracting(o))
    let removed = Array(o.subtracting(n))
    return (added, removed)
}

struct TaxonomyChip: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            Text(name)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct TaxonomyListEditor: View {
    let title: String
    let placeholder: String
    @Binding var items: [String]
    let onDelta: (_ added: [String], _ removed: [String]) -> Void
    var catalog: [String] = []

    @State private var draft: String = ""
    @State private var lastCommitted: [String] = []

    private var filteredUnion: [String] {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // Exclude items from catalog
        let base = Set(catalog).subtracting(items)
        let sorted = base.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        if trimmed.isEmpty { return sorted }
        return sorted.filter { name in
            name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
    

            // Chips-style list with delete
            WrapHStack(spacing: 6, lineSpacing: 6) {
                Text(title).font(.headline)
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 6) {
                        Text(item)
                        Button(role: .destructive) {
                            items.removeAll { $0 == item }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 12).strokeBorder())
                }
            }

            HStack {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addDraft)
                Button("Add") { addDraft() }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
    
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(alignment: .center, spacing: 8) {
                        ForEach(filteredUnion, id: \.self) { name in
                            let selected: Bool = items.contains(name)
                            TaxonomyChip(name: name, isSelected: selected) {
                                toggle(name)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 56)
  

        }
        .onAppear { lastCommitted = items }
        .onChange(of: items) { _, new in
            let d = delta(old: lastCommitted, new: new)
            if !d.added.isEmpty || !d.removed.isEmpty {
                onDelta(d.added, d.removed)
                lastCommitted = new
            }
        }
    }

    private func addDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !items.contains(trimmed) {
            items.append(trimmed)
        }
        draft = ""
    }

    private func toggle(_ name: String) {
        var new = items
        if let idx = new.firstIndex(of: name) {
            new.remove(at: idx)
        } else {
            new.append(name)
        }
        // trigger delta by assigning which will hit onChange below
        items = new
    }
}

// Simple wrapping HStack for chips
struct WrapHStack<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    var body: some View {
        _WrapHStack(spacing: spacing, lineSpacing: lineSpacing) {
            content()
        }
    }
}

private struct _WrapHStack: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        var size = layout(subviews: subviews, in: proposal, place: false)
        size.height += lineSpacing
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        _ = layout(subviews: subviews, in: ProposedViewSize(width: bounds.width, height: bounds.height), place: true, origin: bounds.origin)
    }

    @discardableResult
    private func layout(subviews: Subviews, in proposal: ProposedViewSize, place: Bool, origin: CGPoint = .zero) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x = origin.x
        var y = origin.y
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize.unspecified)
            if x + size.width > (origin.x + maxWidth) && x > origin.x {
                x = origin.x
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            if place {
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let width: CGFloat
        if maxWidth.isFinite {
            width = maxWidth
        } else {
            width = x - origin.x
        }
        return CGSize(width: width, height: (y - origin.y) + lineHeight)
    }
}

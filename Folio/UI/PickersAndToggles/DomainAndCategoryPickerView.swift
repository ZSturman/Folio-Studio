//
//  DomainCategoryPickerView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI
import SwiftData

struct DomainCategoryPickerView: View {
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Environment(\.modelContext) private var modelContext
    @Binding var document: FolioDocument

    // Catalog
    @Query(sort: [SortDescriptor(\ProjectDomain.name)])
    private var domains: [ProjectDomain]

    @Query(sort: [SortDescriptor(\ProjectCategory.name)])
    private var allCategories: [ProjectCategory]

    private var selectedDomainBinding: Binding<ProjectDomain?> {
        Binding<ProjectDomain?>(
            get: {
                guard let dn = document.domain else { return nil }
                return domains.first(where: { $0.name == dn })
            },
            set: { newValue in
                if let d = newValue {
                    document.domain = d.name
                    // Default category to first in this domain when domain changes
                    let firstCat = allCategories.filter { $0.domain.id == d.id }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.first
                    document.category = firstCat?.name
                } else {
                    document.domain = nil
                    document.category = nil
                }
            }
        )
    }

    private var selectedCategoryBinding: Binding<ProjectCategory?> {
        Binding<ProjectCategory?>(
            get: {
                guard let cn = document.category, let sd = selectedDomainBinding.wrappedValue else { return nil }
                let cats = allCategories.filter { $0.domain.id == sd.id }
                return cats.first(where: { $0.name == cn })
            },
            set: { newValue in
                if let c = newValue { document.category = c.name } else { document.category = nil }
            }
        )
    }

    private var categoriesForSelectedDomain: [ProjectCategory] {
        guard let d = selectedDomainBinding.wrappedValue else { return [] }
        return allCategories.filter { $0.domain.id == d.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HStack {

            // Domain row
            HStack(spacing: 8) {
                Picker("Domain", selection: selectedDomainBinding) {
                    Text("None").tag(nil as ProjectDomain?)
                    ForEach(domains, id: \.id) { d in
                        Text(d.name).tag(d as ProjectDomain?)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.large)
                .frame(minWidth: 180, alignment: .leading)

                Button {
                    newDomainName = ""
                    showAddDomainSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Domain")
            }

            // Category row
            HStack(spacing: 8) {
                Picker("Category", selection: selectedCategoryBinding) {
                    Text("None").tag(nil as ProjectCategory?)
                    ForEach(categoriesForSelectedDomain, id: \.id) { c in
                        Text(c.name).tag(c as ProjectCategory?)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.large)
                .frame(minWidth: 180, alignment: .leading)
                .disabled(selectedDomainBinding.wrappedValue == nil)

                Button {
                    newCategoryName = ""
                    showAddCategorySheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Category")
                .disabled(selectedDomainBinding.wrappedValue == nil)
            }
        }
        .padding()
        .onChange(of: document.domain) { _, newValue in
            Task {
                let r = sdc.enqueueDomainChange(newValue ?? "", for: document.id)
                if case .failure(let e) = r { print("[DomainFieldView] enqueueDomainChange error: \(e)") }
            }
        }
        .onChange(of: document.category) { _, newValue in
            Task {
                let r = sdc.enqueueCategoryChange(newValue ?? "", for: document.id)
                if case .failure(let e) = r { print("[CategoryFieldView] enqueueCategoryChange error: \(e)") }
            }
        }

        // Sheets
        .sheet(isPresented: $showAddDomainSheet) {
            AddNameSheet(
                title: "New Domain",
                placeholder: "e.g. Mobile",
                name: $newDomainName,
                contextView: { EmptyView() },
                onCancel: { newDomainName = "" },
                onSave: {
                    addDomain(named: newDomainName.trimmingCharacters(in: .whitespacesAndNewlines))
                    newDomainName = ""
                }
            )
        }

        .sheet(isPresented: $showAddCategorySheet) {
            AddNameSheet(
                title: "New Category",
                placeholder: "e.g. iOS App",
                name: $newCategoryName,
                contextView: {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Domain") { Text(selectedDomainBinding.wrappedValue?.name ?? "None") }
                    }
                },
                onCancel: { newCategoryName = "" },
                onSave: {
                    addCategory(named: newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines))
                    newCategoryName = ""
                }
            )
        }
    }

    // Add new UI state
    @State private var showAddDomainSheet = false
    @State private var showAddCategorySheet = false
    @State private var newDomainName = ""
    @State private var newCategoryName = ""

    // MARK: Helpers
    private func addDomain(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing = domains.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            document.domain = existing.name
            // default category
            document.category = categoriesForSelectedDomain.first?.name
            return
        }

        guard let new = try? ProjectDomain(name: trimmed, in: modelContext, addedVia: .manual) else { return }
        modelContext.insert(new)
        try? modelContext.save()

        document.domain = new.name
        document.category = categoriesForSelectedDomain.first?.name
    }

    private func addCategory(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let domain = selectedDomainBinding.wrappedValue, !trimmed.isEmpty else { return }

        if let existing = categoriesForSelectedDomain.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            document.category = existing.name
            return
        }

        guard let new = try? ProjectCategory(name: trimmed, domain: domain, in: modelContext, addedVia: .manual) else { return }
        modelContext.insert(new)
        try? modelContext.save()

        document.category = new.name
    }
}

// MARK: Reusable sheet
private struct AddNameSheet<Context: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let placeholder: String
    @Binding var name: String
    @ViewBuilder var contextView: () -> Context
    var onCancel: () -> Void
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section { contextView() }.opacity(0)
                Section {
                    TextField(placeholder, text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(handleSave)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: handleSave)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 380)
    }

    private func handleSave() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onSave()
        dismiss()
    }
}


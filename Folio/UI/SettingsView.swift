//
//  SettingsView.swift
//  Folio
//
//  Updated to show and manage tags, domains/categories, mediums, genres, subjects, topics.
//  Inline rename, delete per item, shows addedVia chip.
//
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("refreshInterval") private var refreshInterval = 15
    @AppStorage("theme") private var theme: Theme = .system

    @State private var showResetConfirm = false
    @State private var showAddDomainSheet = false
    @State private var newDomainName = ""

    // MARK: - SwiftData queries
    @Query(sort: \ProjectTag.name, animation: .default) private var tags: [ProjectTag]
    @Query(sort: \ProjectDomain.name, animation: .default) private var domains: [ProjectDomain]
    @Query(sort: \ProjectMedium.name, animation: .default) private var mediums: [ProjectMedium]
    @Query(sort: \ProjectGenre.name, animation: .default) private var genres: [ProjectGenre]
    @Query(sort: \ProjectSubject.name, animation: .default) private var subjects: [ProjectSubject]
    @Query(sort: \ProjectTopic.name, animation: .default) private var topics: [ProjectTopic]

    var body: some View {
        Form {
            // MARK: General
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Stepper("Refresh every \(refreshInterval) min",
                        value: $refreshInterval,
                        in: 1...120)
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases) {
                        Text($0.title).tag($0)
                    }
                }
            }

            // MARK: Presets
            Section("Presets") {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text("Reset default presets")
                }
                .confirmationDialog(
                    "Reset default presets?",
                    isPresented: $showResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        Task { @MainActor in
                            try? resetPresets(in: context)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
                Text("Restores all system-provided statuses, phases, and resource types. User-created items stay untouched.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // MARK: Catalogs
            Section("Catalogs") {
                // Tags
                TaxonomyList(
                    title: "Tags",
                    items: tags,
                    deleteAction: { item in
                        context.delete(item)
                        try? context.save()
                    }
                )

                // Domains → Categories
                DisclosureGroup {
                    if domains.isEmpty {
                        Text("No domains yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(domains) { domain in
                            DomainWithCategoriesRow(domain: domain)
                                .environment(\.modelContext, context)
                            Divider()
                        }
                    }
                } label: {
                    HStack {
                        Text("Domains")
                        Spacer()
                        CountPill(count: domains.count)
                        Button("Add") { showAddDomainSheet = true }
                            .buttonStyle(.bordered)
                    }
                }

                // Mediums
                TaxonomyList(
                    title: "Mediums",
                    items: mediums,
                    deleteAction: { item in
                        context.delete(item)
                        try? context.save()
                    }
                )

                // Genres
                TaxonomyList(
                    title: "Genres",
                    items: genres,
                    deleteAction: { item in
                        context.delete(item)
                        try? context.save()
                    }
                )

                // Subjects
                TaxonomyList(
                    title: "Subjects",
                    items: subjects,
                    deleteAction: { item in
                        context.delete(item)
                        try? context.save()
                    }
                )

                // Topics
                TaxonomyList(
                    title: "Topics",
                    items: topics,
                    deleteAction: { item in
                        context.delete(item)
                        try? context.save()
                    }
                )
            }
        }
        .sheet(isPresented: $showAddDomainSheet) {
            AddDomainSheet(newDomainName: $newDomainName) { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { return }

                do {
                    let domain = try ProjectDomain(name: trimmed, in: context, addedVia: .manual)
                    context.insert(domain)
                    try context.save()
                } catch {
                    // silently ignore on failure
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480)
    }
}

enum Theme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

// MARK: - Reusable Views

/// Generic single-level list for any @Model that has `name` and `addedVia`.
private struct TaxonomyList<Item: PersistentModel & Identifiable>: View where Item.ID == UUID {
    let title: String
    let items: [Item]
    let deleteAction: (Item) -> Void

    var body: some View {
        DisclosureGroup {
            if items.isEmpty {
                Text("No \(title.lowercased()).")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    // We need a type-erased row because we cannot access properties through protocol here.
                    // Each supported type is handled via runtime dispatch below.
                    AnyTaxonomyRow(item: item, onDelete: { deleteAction(item) })
                    Divider()
                }
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                CountPill(count: items.count)
            }
        }
    }
}

/// A small numeric pill for counts.
private struct CountPill: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.15), in: Capsule())
    }
}

/// Inline editor for a single taxonomy item with rename and delete support.
/// This type-erases across supported models.
private struct AnyTaxonomyRow<Item: PersistentModel & Identifiable>: View where Item.ID == UUID {
    @Environment(\.modelContext) private var context
    let item: Item
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var draftName: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // Name or TextField
            Group {
                if isEditing {
                    TextField("Name", text: $draftName, onCommit: commitRename)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            draftName = readName()
                        }
                        .frame(maxWidth: 260)
                } else {
                    Text(readName())
                        .fontWeight(.medium)
                }
            }

            Spacer(minLength: 8)

            AddedViaChip(addedVia: readAddedVia())

            // Row actions
            HStack(spacing: 8) {
                Button(isEditing ? "Save" : "Rename") {
                    if isEditing {
                        commitRename()
                    } else {
                        draftName = readName()
                        isEditing = true
                    }
                }
                .buttonStyle(.bordered)

                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.bordered)
            }
        }
        .onSubmit(commitRename)
    }

    // MARK: accessors per supported model type

    private func readName() -> String {
        switch item {
        case let t as ProjectTag: return t.name
        case let m as ProjectMedium: return m.name
        case let g as ProjectGenre: return g.name
        case let s as ProjectSubject: return s.name
        case let tp as ProjectTopic: return tp.name
        default: return "Unknown"
        }
    }

    private func readAddedVia() -> AddedViaOption {
        switch item {
        case let t as ProjectTag: return t.addedVia
        case let m as ProjectMedium: return m.addedVia
        case let g as ProjectGenre: return g.addedVia
        case let s as ProjectSubject: return s.addedVia
        case let tp as ProjectTopic: return tp.addedVia
        default: return .manual
        }
    }

    private func commitRename() {
        guard isEditing else { return }
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newName.isEmpty == false, newName != readName() else {
            isEditing = false
            return
        }

        do {
            switch item {
            case let t as ProjectTag:
                @Bindable var b = t
                try b.rename(to: newName, in: context)
            case let m as ProjectMedium:
                @Bindable var b = m
                try b.rename(to: newName, in: context)
            case let g as ProjectGenre:
                @Bindable var b = g
                try b.rename(to: newName, in: context)
            case let s as ProjectSubject:
                @Bindable var b = s
                try b.rename(to: newName, in: context)
            case let tp as ProjectTopic:
                @Bindable var b = tp
                try b.rename(to: newName, in: context)
            default:
                break
            }
            try context.save()
        } catch {
            // You could surface an alert here if desired.
            // For now silently ignore on failure.
        }
        isEditing = false
    }
}

/// Row that renders a domain with its categories, supports rename and delete for both.
private struct DomainWithCategoriesRow: View {
    @Environment(\.modelContext) private var context

    @State private var isEditingDomain = false
    @State private var draftDomainName = ""
    @State private var showAddCategorySheet = false
    @State private var newCategoryName = ""

    @Bindable var domain: ProjectDomain

    var body: some View {
        DisclosureGroup {
            // Domain header
            HStack(alignment: .firstTextBaseline) {
                if isEditingDomain {
                    TextField("Domain", text: $draftDomainName, onCommit: commitDomainRename)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { draftDomainName = domain.name }
                        .frame(maxWidth: 260)
                } else {
                    Text(domain.name).fontWeight(.semibold)
                }

                Spacer(minLength: 8)
                AddedViaChip(addedVia: domain.addedVia)

                HStack(spacing: 8) {
                    Button(isEditingDomain ? "Save" : "Rename") {
                        if isEditingDomain { commitDomainRename() }
                        else {
                            draftDomainName = domain.name
                            isEditingDomain = true
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Add Category") { showAddCategorySheet = true }
                        .buttonStyle(.bordered)

                    Button("Delete", role: .destructive) {
                        context.delete(domain)
                        try? context.save()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 4)

            // Categories
            let cats = (domain.categories).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if cats.isEmpty {
                Text("No categories.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cats) { category in
                    CategoryRow(category: category)
                        .environment(\.modelContext, context)
                    Divider()
                }
            }
        } label: {
            HStack {
                Text(domain.name)
                Spacer()
                AddedViaChip(addedVia: domain.addedVia)
                CountPill(count: domain.categories.count)
            }
        }
        .sheet(isPresented: $showAddCategorySheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New Category in \(domain.name)").font(.title3)
                TextField("e.g. iOS App", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                HStack {
                    Spacer()
                    Button("Cancel") { newCategoryName = ""; showAddCategorySheet = false }
                    Button("Save") {
                        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if name.isEmpty == false {
                            if let _ = try? ProjectCategory(name: name, domain: domain, in: context, addedVia: .manual) {
                                if let new = try? ProjectCategory(name: name, domain: domain, in: context, addedVia: .manual) {
                                    context.insert(new)
                                    try? context.save()
                                }
                            } else {
                                // ignore errors
                            }
                        }
                        newCategoryName = ""
                        showAddCategorySheet = false
                    }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 360)
        }
    }

    private func commitDomainRename() {
        guard isEditingDomain else { return }
        let newName = draftDomainName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newName.isEmpty == false, newName != domain.name else {
            isEditingDomain = false
            return
        }
        do {
            try domain.rename(to: newName, in: context)
            try context.save()
        } catch {
            // Optionally surface error
        }
        isEditingDomain = false
    }
}

private struct CategoryRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var category: ProjectCategory

    @State private var isEditing = false
    @State private var draftName = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if isEditing {
                TextField("Category", text: $draftName, onCommit: commitRename)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { draftName = category.name }
                    .frame(maxWidth: 260)
            } else {
                Text(category.name)
            }
            Spacer(minLength: 8)
            AddedViaChip(addedVia: category.addedVia)

            HStack(spacing: 8) {
                Button(isEditing ? "Save" : "Rename") {
                    if isEditing { commitRename() }
                    else {
                        draftName = category.name
                        isEditing = true
                    }
                }
                .buttonStyle(.bordered)

                Button("Delete", role: .destructive) {
                    context.delete(category)
                    try? context.save()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func commitRename() {
        guard isEditing else { return }
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newName.isEmpty == false, newName != category.name else {
            isEditing = false
            return
        }
        do {
            try category.rename(to: newName, in: context)
            try context.save()
        } catch {
            // Optionally surface error
        }
        isEditing = false
    }
}

/// Pill view for the AddedViaOption.
private struct AddedViaChip: View {
    let addedVia: AddedViaOption
    var body: some View {
        Text(addedVia.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.15), in: Capsule())
            .help("addedVia")
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SettingsView()
            .modelContainer(for: [
                ProjectTag.self,
                ProjectDomain.self,
                ProjectCategory.self,
                ProjectMedium.self,
                ProjectGenre.self,
                ProjectSubject.self,
                ProjectTopic.self
            ], inMemory: true)
    }
}

private struct AddDomainSheet: View {
    @Binding var newDomainName: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Domain").font(.title3)
            TextField("e.g. Mobile", text: $newDomainName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
            HStack {
                Spacer()
                Button("Cancel") { newDomainName = ""; dismiss() }
                Button("Save") {
                    let name = newDomainName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.isEmpty == false { onSave(name) }
                    newDomainName = ""
                    dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}


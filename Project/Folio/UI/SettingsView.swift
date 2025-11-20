//
//  SettingsView.swift
//  Folio
//
//  Updated to show and manage tags, domains/categories, mediums, genres, subjects, topics.
//  Inline rename, delete per item, shows addedVia chip.
//
import SwiftUI
import SwiftData

enum SettingsTab: String, CaseIterable, Identifiable {
    case classifications = "Classifications"
    case preferences = "Preferences"
    
    var id: String { rawValue }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("launcherAutoOpen") private var launcherAutoOpen = true
    @AppStorage("theme") private var theme: Theme = .system
    @AppStorage("imageCopyStrategy") private var imageCopyStrategy: ImageCopyStrategy = .immediateCopy
    @AppStorage("customFields") private var customFieldsData: Data = Data()

    @State private var selectedTab: SettingsTab = .classifications
    @State private var showResetConfirm = false
    @State private var showAddDomainSheet = false
    @State private var newDomainName = ""
    @State private var showAddCustomFieldSheet = false
    @State private var customFields: [CustomFieldDefinition] = []
    @State private var newCustomFieldName = ""
    @State private var newCustomFieldType: JSONType = .string

    // MARK: - SwiftData queries
    @Query(sort: \ProjectTag.name, animation: .default) private var tags: [ProjectTag]
    @Query(sort: \ProjectDomain.name, animation: .default) private var domains: [ProjectDomain]
    @Query(sort: \ProjectMedium.name, animation: .default) private var mediums: [ProjectMedium]
    @Query(sort: \ProjectGenre.name, animation: .default) private var genres: [ProjectGenre]
    @Query(sort: \ProjectSubject.name, animation: .default) private var subjects: [ProjectSubject]
    @Query(sort: \ProjectTopic.name, animation: .default) private var topics: [ProjectTopic]

    var body: some View {
        NavigationSplitView {
            // Secondary Sidebar
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Text(tab.rawValue)
                    .tag(tab)
            }
            .navigationTitle("Settings")
            .frame(minWidth: 180)
        } detail: {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: Presets (always visible)
                    GroupBox("Presets") {
                        VStack(alignment: .leading, spacing: 12) {
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    }
                    
                    // Tab-specific content
                    switch selectedTab {
                    case .classifications:
                        classificationsView
                    case .preferences:
                        preferencesView
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 480)
        }
        .onAppear {
            loadCustomFields()
        }
    }
    
    // MARK: - Classifications Tab
    
    @ViewBuilder
    private var classificationsView: some View {
        GroupBox("Classifications") {
            VStack(alignment: .leading, spacing: 16) {
                // Tags - Always Expanded
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tags")
                            .font(.headline)
                        Spacer()
                        CountPill(count: tags.count)
                    }
                    
                    if tags.isEmpty {
                        Text("No tags.")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    } else {
                        ForEach(tags) { item in
                            AnyTaxonomyRow(item: item, onDelete: {
                                context.delete(item)
                                try? context.save()
                            })
                            .padding(.leading, 16)
                            if item.id != tags.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Domains - Always Expanded
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Domains")
                            .font(.headline)
                        Spacer()
                        CountPill(count: domains.count)
                        Button("Add") { showAddDomainSheet = true }
                            .buttonStyle(.bordered)
                    }
                    
                    if domains.isEmpty {
                        Text("No domains yet.")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    } else {
                        ForEach(domains) { domain in
                            DomainWithCategoriesRow(domain: domain)
                                .environment(\.modelContext, context)
                                .padding(.leading, 16)
                            if domain.id != domains.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Mediums - Always Expanded
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Mediums")
                            .font(.headline)
                        Spacer()
                        CountPill(count: mediums.count)
                    }
                    
                    if mediums.isEmpty {
                        Text("No mediums.")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    } else {
                        ForEach(mediums) { item in
                            AnyTaxonomyRow(item: item, onDelete: {
                                context.delete(item)
                                try? context.save()
                            })
                            .padding(.leading, 16)
                            if item.id != mediums.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Genres - Always Expanded
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Genres")
                            .font(.headline)
                        Spacer()
                        CountPill(count: genres.count)
                    }
                    
                    if genres.isEmpty {
                        Text("No genres.")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    } else {
                        ForEach(genres) { item in
                            AnyTaxonomyRow(item: item, onDelete: {
                                context.delete(item)
                                try? context.save()
                            })
                            .padding(.leading, 16)
                            if item.id != genres.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Subjects - Always Expanded
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Subjects")
                            .font(.headline)
                        Spacer()
                        CountPill(count: subjects.count)
                    }
                    
                    if subjects.isEmpty {
                        Text("No subjects.")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    } else {
                        ForEach(subjects) { item in
                            AnyTaxonomyRow(item: item, onDelete: {
                                context.delete(item)
                                try? context.save()
                            })
                            .padding(.leading, 16)
                            if item.id != subjects.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Topics - Always Expanded
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Topics")
                            .font(.headline)
                        Spacer()
                        CountPill(count: topics.count)
                    }
                    
                    if topics.isEmpty {
                        Text("No topics.")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 16)
                    } else {
                        ForEach(topics) { item in
                            AnyTaxonomyRow(item: item, onDelete: {
                                context.delete(item)
                                try? context.save()
                            })
                            .padding(.leading, 16)
                            if item.id != topics.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
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
    }
    
    // MARK: - Preferences Tab
    
    @ViewBuilder
    private var preferencesView: some View {
        GroupBox("Preferences") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Open launcher automatically when no documents are open", isOn: $launcherAutoOpen)
                    .help("When enabled, the launcher window will automatically appear when all documents are closed.")
                
                Divider()
                
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .help("Choose the appearance theme for the application.")
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image Copy Strategy")
                        .font(.headline)
                    
                    Picker("Image Copy Strategy", selection: $imageCopyStrategy) {
                        ForEach(ImageCopyStrategy.allCases) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    
                    Text(imageCopyStrategy.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        
        GroupBox("Custom Fields") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Define custom fields that will appear in the Details tab of all documents.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if customFields.isEmpty {
                    Text("No custom fields defined")
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(customFields) { field in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.name)
                                        .font(.body)
                                    Text(field.type.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    deleteCustomField(field)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Delete custom field")
                            }
                            .padding(.vertical, 4)
                            
                            if field.id != customFields.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                
                Button {
                    showAddCustomFieldSheet = true
                } label: {
                    Label("Add Custom Field", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .sheet(isPresented: $showAddCustomFieldSheet) {
            AddCustomFieldSheet(
                fieldName: $newCustomFieldName,
                fieldType: $newCustomFieldType,
                onSave: { name, type in
                    addCustomField(name: name, type: type)
                }
            )
        }
    }
    
    // MARK: - Custom Fields Management
    
    private func loadCustomFields() {
        guard !customFieldsData.isEmpty else {
            customFields = []
            return
        }
        
        do {
            customFields = try JSONDecoder().decode([CustomFieldDefinition].self, from: customFieldsData)
        } catch {
            print("Failed to decode custom fields: \(error)")
            customFields = []
        }
    }
    
    private func saveCustomFields() {
        do {
            customFieldsData = try JSONEncoder().encode(customFields)
        } catch {
            print("Failed to encode custom fields: \(error)")
        }
    }
    
    private func addCustomField(name: String, type: JSONType) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newField = CustomFieldDefinition(name: trimmedName, type: type)
        customFields.append(newField)
        saveCustomFields()
        
        // Reset form
        newCustomFieldName = ""
        newCustomFieldType = .string
    }
    
    private func deleteCustomField(_ field: CustomFieldDefinition) {
        customFields.removeAll { $0.id == field.id }
        saveCustomFields()
    }
}

// MARK: - Add Custom Field Sheet

private struct AddCustomFieldSheet: View {
    @Binding var fieldName: String
    @Binding var fieldType: JSONType
    var onSave: (String, JSONType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Custom Field")
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Field Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g., Client Name", text: $fieldName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Field Type")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Type", selection: $fieldType) {
                    ForEach(JSONType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    fieldName = ""
                    dismiss()
                }
                Button("Add") {
                    onSave(fieldName, fieldType)
                    dismiss()
                }
                .disabled(fieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

enum Theme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ImageCopyStrategy: String, CaseIterable, Identifiable, Codable {
    case immediateCopy = "immediateCopy"
    case showButton = "showButton"
    case keepOriginal = "keepOriginal"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .immediateCopy: return "Copy Immediately"
        case .showButton: return "Show Copy Button"
        case .keepOriginal: return "Keep in Original Location"
        }
    }
    
    var description: String {
        switch self {
        case .immediateCopy:
            return "Original images are automatically copied to the assets folder when selected."
        case .showButton:
            return "A button appears to let you copy the original image to assets folder when ready."
        case .keepOriginal:
            return "Images stay in their original location. Only edited versions are copied to assets folder."
        }
    }
}

// MARK: - Reusable Views

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


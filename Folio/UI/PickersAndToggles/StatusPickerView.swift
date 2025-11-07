//
//  StatusPickerView.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI
import SwiftData

struct ProjectStatusPickerView: View {
    @EnvironmentObject var sdc: SwiftDataCoordinator
    @Environment(\.modelContext) private var modelContext
    @Binding var document: FolioDocument


    // Catalog
    @Query(sort: [SortDescriptor(\ProjectStatus.name)])
    private var statuses: [ProjectStatus]

    @Query(sort: [SortDescriptor(\ProjectStatusPhase.name)])
    private var allPhases: [ProjectStatusPhase]

    private var selectedStatusBinding: Binding<ProjectStatus?> {
        Binding<ProjectStatus?>(
            get: {
                guard let name = document.status else { return nil }
                return statuses.first(where: { $0.name == name })
            },
            set: { newValue in
                if let s = newValue {
                    document.status = s.name
                    // Default phase to first in that status
                    let first = allPhases.filter { $0.status.id == s.id }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        .first
                    document.phase = first?.name
                } else {
                    document.status = nil
                    document.phase = nil
                }
            }
        )
    }

    private var selectedPhaseBinding: Binding<ProjectStatusPhase?> {
        Binding<ProjectStatusPhase?>(
            get: {
                guard let phaseName = document.phase, let ss = selectedStatusBinding.wrappedValue else { return nil }
                let options = allPhases.filter { $0.status.id == ss.id }
                return options.first(where: { $0.name == phaseName })
            },
            set: { newValue in
                if let p = newValue { document.phase = p.name } else { document.phase = nil }
            }
        )
    }

    private var phasesForSelectedStatus: [ProjectStatusPhase] {
        guard let s = selectedStatusBinding.wrappedValue else { return [] }
        return allPhases.filter { $0.status.id == s.id }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HStack(spacing: 12) {

            // Status row
            HStack(spacing: 8) {
                Picker("Status", selection: selectedStatusBinding) {
                    Text("None").tag(nil as ProjectStatus?)
                    ForEach(statuses, id: \.id) { s in
                        Text(s.name).tag(s as ProjectStatus?)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.large)
                .frame(minWidth: 180, alignment: .leading)

                Button {
                    newStatusName = ""
                    showAddStatusSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Status")
            }

            // Phase row
            HStack(spacing: 8) {
                Picker("Phase", selection: selectedPhaseBinding) {
                    Text("None").tag(nil as ProjectStatusPhase?)
                    ForEach(phasesForSelectedStatus, id: \.id) { p in
                        Text(p.name).tag(p as ProjectStatusPhase?)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.large)
                .frame(minWidth: 180, alignment: .leading)
                .disabled(selectedStatusBinding.wrappedValue == nil)

                Button {
                    newPhaseName = ""
                    showAddPhaseSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Phase for selected Status")
                .disabled(selectedStatusBinding.wrappedValue == nil)
            }
        }
        .padding()
        .onChange(of: document.status) { _, newValue in
            Task {
                if let v = newValue {
                    let r = sdc.enqueueStatusChange(v, for: document.id)
                    if case .failure(let e) = r { print("[StatusFieldView] enqueueStatusChange error: \(e)") }
                }
            }
        }
        .onChange(of: document.phase) { _, newValue in
            Task {
                if let p = newValue {
                    let r = sdc.enqueueStatusPhaseChange(p, for: document.id)
                    if case .failure(let e) = r { print("[PhaseFieldView] enqueueStatusPhaseChange error: \(e)") }
                }
            }
        }

        // Add Status sheet
        .sheet(isPresented: $showAddStatusSheet) {
            AddNameSheet(
                title: "New Status",
                placeholder: "e.g. In Progress",
                name: $newStatusName,
                contextView: { EmptyView() },
                onCancel: { newStatusName = "" },
                onSave: {
                    addStatus(named: newStatusName.trimmingCharacters(in: .whitespacesAndNewlines))
                    newStatusName = ""
                }
            )
            .presentationDetents([.medium])
        }

        .sheet(isPresented: $showAddPhaseSheet) {
            AddNameSheet(
                title: "New Phase",
                placeholder: "e.g. Design",
                name: $newPhaseName,
                contextView: {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Status") { Text(selectedStatusBinding.wrappedValue?.name ?? "None") }
                    }
                },
                onCancel: { newPhaseName = "" },
                onSave: {
                    addPhase(named: newPhaseName.trimmingCharacters(in: .whitespacesAndNewlines))
                    newPhaseName = ""
                }
            )
            .presentationDetents([.medium])
        }
    }

    // Add new UI state
    @State private var showAddStatusSheet = false
    @State private var showAddPhaseSheet = false
    @State private var newStatusName = ""
    @State private var newPhaseName = ""

    // MARK: - Behaviors
    private func addStatus(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing = statuses.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            document.status = existing.name
            document.phase = phasesForSelectedStatus.first?.name
            return
        }

        guard let new = try? ProjectStatus(name: trimmed, in: modelContext, addedVia: .manual) else { return }
        modelContext.insert(new)
        try? modelContext.save()

        document.status = new.name
        document.phase = phasesForSelectedStatus.first?.name
    }

    private func addPhase(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let status = selectedStatusBinding.wrappedValue, !trimmed.isEmpty else { return }

        if let existing = phasesForSelectedStatus.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            document.phase = existing.name
            return
        }

        guard let new = try? ProjectStatusPhase(name: trimmed, status: status, in: modelContext, addedVia: .manual) else { return }
        modelContext.insert(new)
        try? modelContext.save()

        document.phase = new.name
    }
}

// MARK: - Reusable sheet

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
                // Optional context header
                Section {
                    contextView()
                }
                .opacity(isContextEmpty ? 0 : 1)

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
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: handleSave)
                        .keyboardShortcut(.defaultAction)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 380) // macOS-friendly width
    }

    private var isContextEmpty: Bool {
        // crude check: render empty view as zero height
        // caller passes EmptyView() when no context desired
        false // Always show section shell for consistent spacing
    }

    private func handleSave() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSave()
        dismiss()
    }
}

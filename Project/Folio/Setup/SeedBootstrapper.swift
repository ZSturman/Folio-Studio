//
//  SeedBootstrapper.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import SwiftUI
import SwiftData

struct SeedBootstrapper: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        // Invisible view that runs tasks on launch
        Color.clear
            .task {
                // Guarded one-time seeds
                try? seedIfNeeded_ResourceCatalog(in: context)
                try? seedIfNeeded_ProjectStatusCatalog(in: context)
                try? seedIfNeeded_DomainCatalog(in: context)
            }
    }
}

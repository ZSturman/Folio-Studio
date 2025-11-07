//
//  SidebarTabs.swift
//  Folio
//
//  Created by Zachary Sturman on 11/3/25.
//

import Foundation
import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable, Hashable {
    case basicInfo
    case tagsAndClassification
    case content
    case media
    case collection
    case other
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basicInfo:              return "Basic Info"
        case .collection:             return "Collection"
        case .content:                return "Content"
        case .media:                  return "Media"
        case .tagsAndClassification:  return "Classification"
        case .other:                  return "Other"
        case .settings:               return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .basicInfo:              return "info.circle"
        case .collection:             return "tray"
        case .content:                return "doc.text"
        case .media:                  return "photo.on.rectangle"
        case .tagsAndClassification:  return "tag"
        case .other:                  return "ellipsis.circle"
        case .settings:               return "gear"
        }
    }
}

struct SidebarTabsView: View {
    @Binding var selection: SidebarTab?

    var body: some View {
        List(SidebarTab.allCases, selection: $selection) { tab in
            Label(tab.title, systemImage: tab.systemImage)
                .tag(tab)
        }
        .navigationTitle("Folio")
        .listStyle(.sidebar)
    }
}

#Preview {
    NavigationView {
        SidebarTabsView(selection: .init(get: { nil }, set: { _ in }))
    }
}

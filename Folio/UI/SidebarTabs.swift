//
//  SidebarTabs.swift
//  Folio
//
//  Created by Zachary Sturman on 11/3/25.
//

import Foundation
import SwiftUI



enum BasicInfoSubtab: String, CaseIterable, Identifiable, Hashable {
    case main
    case classification
    case details

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main:           return "Main"
        case .classification: return "Classification"
        case .details:        return "Details"
        }
    }
}

enum ContentSubtab: String, CaseIterable, Identifiable, Hashable {
    case summary
    case description
    case resources

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary:     return "Summary"
        case .description: return "Description"
        case .resources:   return "Resources"
        }
    }
}

enum SidebarTab: String, CaseIterable, Identifiable, Hashable {
    case basicInfo
    case media

    case content
    case collection

    case snippets
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basicInfo:              return "Basic Info"
        case .collection:             return "Collection"
        case .content:                return "Content"
        case .media:                  return "Media"
        case .snippets:               return "Snippets"
        case .settings:               return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .basicInfo:              return "info.circle"
        case .collection:             return "tray"
        case .content:                return "doc.text"
        case .media:                  return "video"
        case .snippets:               return "chevron.left.slash.chevron.right"
        case .settings:               return "gear"
        }
    }
}
  
struct SidebarTabsView: View {
    @Binding var selection: SidebarTab?
    
    private var topTabs: [SidebarTab] {
        SidebarTab.allCases.filter { $0 != .settings && $0 != .snippets }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List(topTabs, selection: $selection) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }

            VStack(spacing: 4) {
                snippetsRow
                settingsRow
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsRow: some View {
        Label(SidebarTab.settings.title, systemImage: SidebarTab.settings.systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(selection == .settings ? Color.accentColor.opacity(0.2) : .clear)
            .contentShape(Rectangle())
            .onTapGesture {
                selection = .settings
            }
    }

    private var snippetsRow: some View {
        Label(SidebarTab.snippets.title, systemImage: SidebarTab.snippets.systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(selection == .snippets ? Color.accentColor.opacity(0.2) : .clear)
            .contentShape(Rectangle())
            .onTapGesture {
                selection = .snippets
            }
    }
}

#Preview {
    NavigationView {
        SidebarTabsView(selection: .init(get: { nil }, set: { _ in }))
    }
}

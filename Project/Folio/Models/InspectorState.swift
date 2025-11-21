//
//  InspectorState.swift
//  Folio
//
//  Created by Zachary Sturman on 11/20/25.
//

import SwiftUI
import Combine

/// Shared state for managing inspector panel across all tabs
final class InspectorState: ObservableObject {
    
    // Inspector visibility (persisted across app launches)
    @AppStorage("inspectorVisible") var isVisible: Bool = true
    
    // Current active tab showing inspector content (persisted)
    @Published var activeTab: SidebarTab? {
        didSet {
            if let tab = activeTab {
                activeTabRawValue = tab.rawValue
            } else {
                activeTabRawValue = nil
            }
        }
    }
    
    @AppStorage("lastActiveInspectorTab") private var activeTabRawValue: String?
    
    // Media tab selection (image label)
    @Published var mediaSelection: String?
    
    // Collection tab selection (collection name, optional item ID)
    @Published var collectionSelection: (collectionName: String, itemId: UUID?)?
    
    init() {
        // Restore last active tab from AppStorage
        if let rawValue = activeTabRawValue {
            self.activeTab = SidebarTab(rawValue: rawValue)
        }
    }
    
    /// Reset all selections (call when document changes)
    func reset() {
        // Don't reset activeTab - it persists across documents
        mediaSelection = nil
        collectionSelection = nil
    }
    
    /// Set media tab as active and select an image
    func selectMedia(_ imageLabel: String) {
        activeTab = .media
        mediaSelection = imageLabel
        isVisible = true
    }
    
    /// Set collection tab as active and optionally select an item
    func selectCollection(_ collectionName: String, item itemId: UUID? = nil) {
        activeTab = .collection
        collectionSelection = (collectionName, itemId)
        isVisible = true
    }
}

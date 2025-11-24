import Foundation
import SwiftUI

public struct PreviewNode: Identifiable, Equatable {
    public let id: UUID
    public let label: String
    public let value: String?
    public let children: [PreviewNode]
    
    public var hasChildren: Bool {
        !children.isEmpty
    }
    
    public init(id: UUID = UUID(), label: String, value: String? = nil, children: [PreviewNode] = []) {
        self.id = id
        self.label = label
        self.value = value
        self.children = children
    }
    
    public static func section(_ title: String, children: [PreviewNode]) -> PreviewNode {
        PreviewNode(label: title, value: nil, children: children)
    }
    
    public static func leaf(label: String, value: String) -> PreviewNode {
        PreviewNode(label: label, value: value, children: [])
    }
}

fileprivate extension DateFormatter {
    static let folioPreviewShort: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        switch self {
        case .none: return true
        case .some(let s): return s.isEmpty
        }
    }
}

private func truncate(_ text: String, max: Int) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > max else { return trimmed }
    let index = trimmed.index(trimmed.startIndex, offsetBy: max)
    return String(trimmed[..<index]) + "…"
}

extension JSONValue {
    func previewSummary(maxLength: Int = 60) -> String {
        switch self {
        case .string(let s):
            return truncate(s, max: maxLength)
        case .number(let n):
            return String(describing: n)
        case .bool(let b):
            return b ? "true" : "false"
        case .array(let a):
            return "Array (\(a.count))"
        case .object(let o):
            return "Object (\(o.keys.count))"
        case .null:
            return "null"
        }
    }
}

extension FolioDocument {
    public func buildPreviewNodes() -> [PreviewNode] {
        var sections: [PreviewNode] = []
        
        // MARK: - Overview Section
        
        var overviewNodes: [PreviewNode] = []
        
        if !title.isEmpty {
            overviewNodes.append(.leaf(label: "Title", value: title))
        }
        if !subtitle.isEmpty {
            overviewNodes.append(.leaf(label: "Subtitle", value: subtitle))
        }
        if !summary.isEmpty {
            overviewNodes.append(.leaf(label: "Summary", value: summary))
        }
        overviewNodes.append(.leaf(label: "Public", value: isPublic ? "Yes" : "No"))
        if featured {
            overviewNodes.append(.leaf(label: "Featured", value: "Yes"))
        }
        if requiresFollowUp {
            overviewNodes.append(.leaf(label: "Requires Follow Up", value: "Yes"))
        }
        if let status, !status.isEmpty {
            overviewNodes.append(.leaf(label: "Status", value: status))
        }
        if let phase, !phase.isEmpty {
            overviewNodes.append(.leaf(label: "Phase", value: phase))
        }
        if let domain, !domain.isEmpty {
            overviewNodes.append(.leaf(label: "Domain", value: domain))
        }
        if let category, !category.isEmpty {
            overviewNodes.append(.leaf(label: "Category", value: category))
        }
        if let created = formatDate(createdAt) {
            overviewNodes.append(.leaf(label: "Created", value: created))
        }
        if let updated = formatDate(updatedAt) {
            overviewNodes.append(.leaf(label: "Updated", value: updated))
        }
        if let folder = assetsFolder, let path = folder.path, !path.isEmpty {
            overviewNodes.append(.leaf(label: "Assets Folder", value: path))
        }
        
        if !images.isEmpty {
            if let mainImageLabel = mainImageLabel(), let mainImagePath = mainImagePath() {
                overviewNodes.append(.leaf(label: mainImageLabel, value: mainImagePath))
            }
        }
        
        if let tagsNode = classifyList(tags, label: "Tags") {
            overviewNodes.append(tagsNode)
        }
        if let mediumsNode = classifyList(mediums, label: "Mediums") {
            overviewNodes.append(mediumsNode)
        }
        if let genresNode = classifyList(genres, label: "Genres") {
            overviewNodes.append(genresNode)
        }
        if let topicsNode = classifyList(topics, label: "Topics") {
            overviewNodes.append(topicsNode)
        }
        if let subjectsNode = classifyList(subjects, label: "Subjects") {
            overviewNodes.append(subjectsNode)
        }
        
        if !overviewNodes.isEmpty {
            sections.append(.section("Overview", children: overviewNodes))
        }
        
        // MARK: - Images Section
        
        if !images.isEmpty {
            let sortedImages = images.sorted { lhs, rhs in
                friendlyImageLabel(from: lhs.key).localizedCaseInsensitiveCompare(friendlyImageLabel(from: rhs.key)) == .orderedAscending
            }
            let imageNodes: [PreviewNode] = sortedImages.map { key, assetPath in
                var value = bestPathSummary(from: assetPath)
#if true
                if let anyID = (assetPath.id as Any?) {
                    if let uuid = anyID as? UUID {
                        let prefix = String(uuid.uuidString.prefix(8))
                        value += " • id: \(prefix)"
                    }
                }
#endif
                return .leaf(label: friendlyImageLabel(from: key), value: value)
            }
            sections.append(.section("Images (\(images.count))", children: imageNodes))
        }
        
        // MARK: - Collections Section
        
        if !collection.isEmpty {
            let sortedCollections = collection.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            let collectionNodes: [PreviewNode] = sortedCollections.map { name, section in
                let itemsCount = section.items.count
                let imagesCount = section.images.count
                var valueComponents: [String] = []
                if itemsCount > 0 {
                    valueComponents.append("\(itemsCount) item" + (itemsCount > 1 ? "s" : ""))
                }
                if imagesCount > 0 {
                    valueComponents.append("\(imagesCount) image" + (imagesCount > 1 ? "s" : ""))
                }
                let value = valueComponents.isEmpty ? nil : valueComponents.joined(separator: ", ")
                
                var children: [PreviewNode] = []
                
                if imagesCount > 0 {
                    let sortedImages = section.images.sorted { lhs, rhs in
                        friendlyImageLabel(from: lhs.key).localizedCaseInsensitiveCompare(friendlyImageLabel(from: rhs.key)) == .orderedAscending
                    }
                    let imageChildren: [PreviewNode] = sortedImages.map { key, assetPath in
                        var val = bestPathSummary(from: assetPath)
#if true
                        if let anyID = (assetPath.id as Any?) {
                            if let uuid = anyID as? UUID {
                                let prefix = String(uuid.uuidString.prefix(8))
                                val += " • id: \(prefix)"
                            }
                        }
#endif
                        return .leaf(label: friendlyImageLabel(from: key), value: val)
                    }
                    children.append(.section("Images (\(imagesCount))", children: imageChildren))
                }
                
                if itemsCount > 0 {
                    let sortedItems = section.items.sorted { lhs, rhs in
                        let lLabel = lhs.label
                        let rLabel = rhs.label
                        if lLabel.localizedCaseInsensitiveCompare(rLabel) == .orderedSame {
                            return lhs.id.uuidString.localizedCaseInsensitiveCompare(rhs.id.uuidString) == .orderedAscending
                        }
                        return lLabel.localizedCaseInsensitiveCompare(rLabel) == .orderedAscending
                    }
                    let itemChildren: [PreviewNode] = sortedItems.map { item in
                        collectionItemNode(item, in: name)
                    }
                    children.append(.section("Items (\(itemsCount))", children: itemChildren))
                }
                
                return .section(name + (value != nil ? " (\(value!))" : ""), children: children)
            }
            sections.append(.section("Collections (\(collection.count))", children: collectionNodes))
        }
        
        // MARK: - Other Fields Section
        
        if !values.isEmpty {
            let sortedKeys = values.keys.sorted()
            let otherNodes: [PreviewNode] = sortedKeys.map { key in
                let summary = values[key]?.previewSummary(maxLength: 60) ?? "null"
                return .leaf(label: key, value: summary)
            }
            sections.append(.section("Other Fields (\(values.count))", children: otherNodes))
        }
        
        // Filter out any empty sections just in case
        return sections.filter { $0.hasChildren }
    }
    
    // MARK: - Private Helpers
    
    private func friendlyImageLabel(from storageKey: String) -> String {
        let label = ImageLabel(storageKey: storageKey).title
        if !label.isEmpty {
            return label
        }
        return storageKey
    }
    
    private func bestPathSummary(from asset: AssetPath) -> String {
        let candidates = [asset.path, asset.pathToEdited, asset.pathToOriginal]
        for candidate in candidates {
            if let str = candidate, !str.isEmpty {
                return filename(from: str)
            }
        }
        return "(missing)"
    }
    
    private func filename(from path: String) -> String {
        // If path looks like a path (contains "/" or "\"), return last path component
        if path.contains("/") || path.contains("\\") {
            return (path as NSString).lastPathComponent
        }
        return path
    }
    
    private func formatDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        return DateFormatter.folioPreviewShort.string(from: date)
    }
    
    private func classifyList(_ list: [String], label: String, maxChars: Int = 120) -> PreviewNode? {
        let filtered = list.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        let joined = filtered.joined(separator: ", ")
        let truncated = truncate(joined, max: maxChars)
        return .leaf(label: label, value: truncated)
    }
    
    private func mainImageLabel() -> String? {
        // Prefer "thumbnail", then "banner", then first available
        if images["thumbnail"] != nil {
            return friendlyImageLabel(from: "thumbnail")
        }
        if images["banner"] != nil {
            return friendlyImageLabel(from: "banner")
        }
        if let first = images.first {
            return friendlyImageLabel(from: first.key)
        }
        return nil
    }
    
    private func mainImagePath() -> String? {
        // Match mainImageLabel selection
        if let thumb = images["thumbnail"] {
            return bestPathSummary(from: thumb)
        }
        if let banner = images["banner"] {
            return bestPathSummary(from: banner)
        }
        if let first = images.first {
            return bestPathSummary(from: first.value)
        }
        return nil
    }
    
    private func itemValueSummary(item: JSONCollectionItem, sectionName: String) -> String {
        let type = item.type.rawValue
        let source: String
        switch item.type {
        case .file:
            if let filePath = item.filePath {
                if !filePath.path.isEmpty {
                    source = filename(from: filePath.path)
                } else {
                    source = "(no file)"
                }
            } else {
                source = "(no file)"
            }
        case .urlLink:
            if let urlString = item.url, !urlString.isEmpty {
                source = truncate(urlString, max: 80)
            } else {
                source = "(no url)"
            }
        case .folio:
            source = "Folio item"
        @unknown default:
            source = "(unknown)"
        }
        return "\(type) • \(source) • \(sectionName)"
    }
    
    private func collectionItemNode(_ item: JSONCollectionItem, in sectionName: String) -> PreviewNode {
        let label = item.label.isEmpty ? "Untitled" : item.label
        let value = itemValueSummaryForNode(item: item)
        let children = itemDetailChildren(item)
        return PreviewNode(id: item.id, label: label, value: value, children: children)
    }
    
    private func itemValueSummaryForNode(item: JSONCollectionItem) -> String {
        let type = item.type.rawValue
        let source: String
        switch item.type {
        case .file:
            if let filePath = item.filePath {
                if !filePath.path.isEmpty {
                    source = filename(from: filePath.path)
                } else if let edited = filePath.pathToEdited, !edited.isEmpty {
                    source = filename(from: edited)
                } else if let original = filePath.pathToOriginal, !original.isEmpty {
                    source = filename(from: original)
                } else {
                    source = "(no file)"
                }
            } else {
                source = "(no file)"
            }
        case .urlLink:
            if let urlString = item.url, !urlString.isEmpty {
                source = truncate(urlString, max: 80)
            } else {
                source = "(no url)"
            }
        case .folio:
            if let urlString = item.url, !urlString.isEmpty {
                source = truncate(urlString, max: 80)
            } else {
                source = "(no project)"
            }
        @unknown default:
            source = "(unknown)"
        }
        return "\(type) • \(source)"
    }
    
    private func itemDetailChildren(_ item: JSONCollectionItem) -> [PreviewNode] {
        var detailNodes: [PreviewNode] = []
        
        // Always include ID leaf with prefix 8 chars
        let idPrefix = String(item.id.uuidString.prefix(8))
        detailNodes.append(.leaf(label: "ID", value: idPrefix))
        
        // Type leaf
        detailNodes.append(.leaf(label: "Type", value: item.type.rawValue))
        
        // Summary leaf if present and non-empty
        if let summary = item.summary, !summary.isEmpty {
            detailNodes.append(.leaf(label: "Summary", value: truncate(summary, max: 120)))
        }
        
        // Source section
        var sourceChildren: [PreviewNode] = []
        switch item.type {
        case .file:
            if let filePath = item.filePath {
                if !filePath.path.isEmpty {
                    var relativeValue = filePath.path
#if true
                    if let anyID = (filePath.id as Any?) {
                        if let uuid = anyID as? UUID {
                            let prefix = String(uuid.uuidString.prefix(8))
                            relativeValue += " • id: \(prefix)"
                        }
                    }
#endif
                    sourceChildren.append(.leaf(label: "Relative", value: relativeValue))
                }
                if let original = filePath.pathToOriginal, !original.isEmpty {
                    sourceChildren.append(.leaf(label: "Original", value: filename(from: original)))
                }
                if let edited = filePath.pathToEdited, !edited.isEmpty {
                    sourceChildren.append(.leaf(label: "Edited", value: filename(from: edited)))
                }
            }
        case .urlLink:
            if let urlString = item.url, !urlString.isEmpty {
                sourceChildren.append(.leaf(label: "URL", value: truncate(urlString, max: 120)))
            }
        case .folio:
            if let urlString = item.url, !urlString.isEmpty {
                sourceChildren.append(.leaf(label: "Folio", value: truncate(urlString, max: 120)))
            }
        @unknown default:
            break
        }
        if !sourceChildren.isEmpty {
            detailNodes.append(.section("Source", children: sourceChildren))
        }
        
        // Thumbnail section
        var thumbnailChildren: [PreviewNode] = []
        let thumb = item.thumbnail
        if !thumb.path.isEmpty {
            var relativeValue = thumb.path
#if true
            if let anyID = (thumb.id as Any?) {
                if let uuid = anyID as? UUID {
                    let prefix = String(uuid.uuidString.prefix(8))
                    relativeValue += " • id: \(prefix)"
                }
            }
#endif
            thumbnailChildren.append(.leaf(label: "Relative", value: relativeValue))
        }
        if let original = thumb.pathToOriginal, !original.isEmpty {
            thumbnailChildren.append(.leaf(label: "Original", value: filename(from: original)))
        }
        if let edited = thumb.pathToEdited, !edited.isEmpty {
            thumbnailChildren.append(.leaf(label: "Edited", value: filename(from: edited)))
        }
        if !thumbnailChildren.isEmpty {
            detailNodes.append(.section("Thumbnail", children: thumbnailChildren))
        }
        
        // Resource section
        var resourceChildren: [PreviewNode] = []
        // Handle optionality of item.resource properly; if it's non-optional this still compiles
        if let resource = (item.resource as JSONResource?) {
            // Treat properties as non-optional strings if they are non-optional; avoid `if let` on non-optional types
            if !resource.label.isEmpty {
                resourceChildren.append(.leaf(label: "Label", value: resource.label))
            }
            if !resource.category.isEmpty {
                resourceChildren.append(.leaf(label: "Category", value: resource.category))
            }
            if !resource.type.isEmpty {
                resourceChildren.append(.leaf(label: "Type", value: resource.type))
            }
            if !resource.url.isEmpty {
                resourceChildren.append(.leaf(label: "URL", value: truncate(resource.url, max: 120)))
            }
        }
        if !resourceChildren.isEmpty {
            detailNodes.append(.section("Resource", children: resourceChildren))
        }
        
        // Order leaf, if item.order exists and is valid
        do {
            // Support both optional and non-optional `order`
            // Use Mirror to detect optionality without changing model types
            let mirror = Mirror(reflecting: item.order as Any)
            if mirror.displayStyle == .optional {
                if let order = (item.order as Int?) {
                    detailNodes.append(.leaf(label: "Order", value: String(order)))
                }
            } else if let nonOptionalOrder = item.order as Int? {
                detailNodes.append(.leaf(label: "Order", value: String(nonOptionalOrder)))
            }
        }
        
        return detailNodes
    }
}

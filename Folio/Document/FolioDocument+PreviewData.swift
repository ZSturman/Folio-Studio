import Foundation
import SwiftUI

// MARK: - FolioDocument Sample/Preview Data
extension FolioDocument {
    /// A single, generic sample document suitable for most previews
    static var preview: FolioDocument { sample(index: 1) }

    /// A small collection of varied sample documents
    static var previews: [FolioDocument] {
        [
            sample(index: 1, title: "Atlas of Daydreams", subtitle: "Explorations in color", featured: true, isPublic: true, tags: ["art", "concept"], mediums: ["digital"], genres: ["abstract"], topics: ["color theory"], subjects: ["geometry"]),
            sample(index: 2, title: "Nocturne", subtitle: "A study in blue", featured: false, isPublic: false, tags: ["painting"], mediums: ["oil"], genres: ["impressionism"], topics: ["night"], subjects: ["cityscape"]),
            sample(index: 3, title: "Field Notes", subtitle: "Textures and patterns", featured: false, isPublic: true, tags: ["photography", "macro"], mediums: ["photo"], genres: ["documentary"], topics: ["nature"], subjects: ["flora"]),
            sample(index: 4, title: "Signal", subtitle: "Kinetic typography", featured: true, isPublic: true, tags: ["motion"], mediums: ["video", "type"], genres: ["experimental"], topics: ["communication"], subjects: ["typography"]),
            sample(index: 5, title: "Sketchbook", subtitle: "Daily studies", featured: false, isPublic: false, tags: ["sketch", "study"], mediums: ["pencil"], genres: ["practice"], topics: ["form"], subjects: ["figure"])
        ]
    }

    /// Create a sample document with sensible defaults and optional overrides
    static func sample(
        id: UUID = UUID(),
        index: Int = 1,
        title: String = "Sample Folio #\(String(describing: index))",
        subtitle: String = "Subtitle #\(String(describing: index))",
        featured: Bool = false,
        isPublic: Bool = true,
        summary: String? = nil,
        domain: String? = nil,
        category: String? = nil,
        status: String? = ["draft", "in-progress", "complete"].randomElement(),
        phase: String? = ["ideation", "production", "review"].randomElement(),
        requiresFollowUp: Bool = false,
        tags: [String] = ["sample", "demo"],
        mediums: [String] = ["digital"],
        genres: [String] = ["concept"],
        topics: [String] = ["design"],
        subjects: [String] = ["general"],
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> FolioDocument {
        var d = FolioDocument()
        let resolvedCreatedAt = createdAt ?? Date().addingTimeInterval(Double(-index) * 86_400)
        let resolvedUpdatedAt = updatedAt ?? Date()

        d.id = id
        d.filePath = nil

        d.title = title
        d.subtitle = subtitle
        d.isPublic = isPublic
        d.summary = summary ?? "This is a short summary for \(title)."
        d.domain = domain
        d.category = category
        d.status = status
        d.phase = phase
        d.featured = featured
        d.requiresFollowUp = requiresFollowUp
        d.createdAt = resolvedCreatedAt
        d.updatedAt = resolvedUpdatedAt

        // Keep media/resources empty to avoid external type dependencies in samples
        d.images = [:]

        d.tags = tags
        d.mediums = mediums
        d.genres = genres
        d.topics = topics
        d.subjects = subjects

        d.description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
        d.story = "\n- Chapter 1: Beginnings\n- Chapter 2: Exploration\n- Chapter 3: Reflection\n"
        d.resources = []
        d.collection = [:]

        // Provide a couple of dynamic key/value extras for realism
        d.values = [
            "priority": .string("normal"),
            "estimateHours": .number(Double(index * 3)),
            "notes": .string("Auto-generated preview data for \(title)")
        ]
        return d
    }

    /// Larger dataset for list/grid previews or testing
    static func many(_ count: Int = 20) -> [FolioDocument] {
        guard count > 0 else { return [] }
        return (1...count).map { i in
            sample(index: i,
                   title: "Folio Item #\(i)",
                   subtitle: i % 2 == 0 ? "Evening study #\(i)" : "Morning study #\(i)",
                   featured: i % 5 == 0,
                   isPublic: i % 3 != 0,
                   tags: i % 2 == 0 ? ["even", "preview"] : ["odd", "preview"],
                   mediums: i % 4 == 0 ? ["video"] : ["digital"],
                   genres: ["concept"],
                   topics: ["design", "art"],
                   subjects: ["general"]) }
    }
}

#if DEBUG
// Convenience for SwiftUI previews
struct FolioDocumentPreviewProvider {
    static let single = FolioDocument.preview
    static let few = FolioDocument.previews
    static let many = FolioDocument.many(50)
}
#endif

//extension FolioDocument {
//    static var collectionPreview: FolioDocument {
//        var d = FolioDocument()
////        d.assetsFolder = FileManager.default.temporaryDirectory
////                  .appendingPathComponent("FolioAssetsPreview")
//        d.collection = [
//            "Photos": CollectionSection(
//                images: [:],
//                items: [
//                    JSONCollectionItem(
//                        id: UUID(),
//                        type: CollectionItemType.file.rawValue,
//                        label: "Sample Photo"
//                    ),
//                    JSONCollectionItem(
//                        id: UUID(),
//                        type: CollectionItemType.file.rawValue,
//                        label: "Notes PDF"
//                    )
//                ]
//            ),
//            "Videos": CollectionSection(
//                images: [:],
//                items: [
//                    JSONCollectionItem(
//                        id: UUID(),
//                        type: CollectionItemType.file.rawValue,
//                        label: "Demo Clip"
//                    )
//                ]
//            )
//        ]
//        return d
//    }
//}

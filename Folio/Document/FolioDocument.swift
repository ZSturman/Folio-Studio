//
//  DocumentParser.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine
import SwiftData


// MARK: - Document
struct FolioDocument: FileDocument, Codable {

    static var readableContentTypes: [UTType] = [.folioDoc, .json]
    static var writableContentTypes: [UTType] = [.folioDoc]

    var id: UUID
    var filePath: URL?
    
    // BASIC DATA
    var title: String
    var subtitle: String
    var isPublic: Bool
    var summary: String
    var domain: String?
    var category: String?
    var status: String?
    var phase: String?
    var featured: Bool
    var requiresFollowUp: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    // MEDIA
    var images: [String: AssetPath] = [:]
    var assetsFolder: URL?
    
    // CLASSIFICATION
    var tags: [String] = []
    
    var mediums: [String] = []
    var genres: [String] = []
    var topics: [String] = []
    var subjects: [String] = []
    
    // CONTENT
    var description: String?
    var story: String?
    var resources: [JSONResource] = []
    
    // COLLECTION
    var collection: [String: [JSONCollectionItem]] = [:]
    
    // OTHER K:V
    var values: [String: JSONValue]

    
    // New empty document
    init() {
        self.id = UUID()
        self.filePath = nil
        
        self.title = ""
        self.subtitle = ""
        self.isPublic = false
        self.summary = ""
        self.featured = false
        self.requiresFollowUp = false
        
        self.values = [:]
        
        
        #if DEBUG
        print("[FolioDocument] init() called; id=\(id), isPublic=\(isPublic), tags=\(tags.count), mediums=\(mediums.count), genres=\(genres.count), topics=\(topics.count), subjects=\(subjects.count)")
        #endif
    }

    // READ hook
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoded = try JSONDecoder().decode(Self.self, from: data)
        self.id = decoded.id
        self.filePath = decoded.filePath
        self.title = decoded.title
        self.subtitle = decoded.subtitle
        self.isPublic = decoded.isPublic
        self.summary = decoded.summary
        self.domain = decoded.domain
        self.category = decoded.category
        self.status = decoded.status
        self.phase = decoded.phase
        self.featured = decoded.featured
        self.requiresFollowUp = decoded.requiresFollowUp
        self.createdAt = decoded.createdAt
        self.updatedAt = decoded.updatedAt
        self.images = decoded.images
        self.assetsFolder = decoded.assetsFolder
        self.tags = decoded.tags
        self.mediums = decoded.mediums
        self.genres = decoded.genres
        self.topics = decoded.topics
        self.subjects = decoded.subjects
        self.description = decoded.description
        self.story = decoded.story
        self.resources = decoded.resources
        self.collection = decoded.collection
        self.values = decoded.values
        
        #if DEBUG
        print("[FolioDocument] init(configuration:) loaded; id=\(id), title=\(title), url=\(filePath?.path ?? "Unknown"), tags=\(tags.count), mediums=\(mediums.count), genres=\(genres.count), topics=\(topics.count), subjects=\(subjects.count), resources=\(resources.count)")
        #endif
    }

    func snapshot(contentType: UTType) throws -> Data {
        #if DEBUG
        print("[FolioDocument] snapshot(contentType:) called; id=\(id), contentType=\(contentType.identifier), title=\(title), onMain=\(Thread.isMainThread)")
        #endif

        // Encode the document state and report size
        let data = try JSONEncoder().encode(self)
        #if DEBUG
        print("[FolioDocument] snapshot encoded; id=\(id), bytes=\(data.count))")
        #endif
        return data
    }
    
    // SAVE hook entry point required by FileDocument
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        #if DEBUG
        print("[FolioDocument] fileWrapper(configuration:) called; id=\(id), contentType=\(configuration.contentType.identifier)")
        #endif
        let data = try snapshot(contentType: configuration.contentType)
        return try fileWrapper(snapshot: data, configuration: configuration)
    }

    // SAVE hook continuation
    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        #if DEBUG
        print("[FolioDocument] fileWrapper called; id=\(id), url=\(filePath?.path ?? "nil"), bytes=\(snapshot.count)")
        #endif
        return .init(regularFileWithContents: snapshot)
    }

    // MARK: Codable
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case filePath

        case title
        case subtitle
        case isPublic
        case summary
        case domain
        case category
        case status
        case phase
        case featured
        case requiresFollowUp
        case createdAt
        case updatedAt
        
        case assetsFolder

        case images
        
        case tags
        case mediums
        case genres
        case topics
        case subjects

        case description
        case story
        case resources

        case collection

    }


    // Decode known keys then sweep remaining into `values`
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.filePath = try c.decodeIfPresent(URL.self, forKey: .filePath)

        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        self.isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.domain = try c.decodeIfPresent(String.self, forKey: .domain)
        self.category = try c.decodeIfPresent(String.self, forKey: .category)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase)
        self.featured = try c.decodeIfPresent(Bool.self, forKey: .featured) ?? false
        self.requiresFollowUp = try c.decodeIfPresent(Bool.self, forKey: .requiresFollowUp) ?? false
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)

        self.images = try c.decodeIfPresent([String: AssetPath].self, forKey: .images) ?? [:]
        self.assetsFolder = try c.decodeIfPresent(URL.self, forKey: .assetsFolder)

        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.mediums = try c.decodeIfPresent([String].self, forKey: .mediums) ?? []
        self.genres = try c.decodeIfPresent([String].self, forKey: .genres) ?? []
        self.topics = try c.decodeIfPresent([String].self, forKey: .topics) ?? []
        self.subjects = try c.decodeIfPresent([String].self, forKey: .subjects) ?? []

        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.story = try c.decodeIfPresent(String.self, forKey: .story)
        self.resources = try c.decodeIfPresent([JSONResource].self, forKey: .resources) ?? []
        self.collection = try c.decodeIfPresent([String: [JSONCollectionItem]].self, forKey: .collection) ?? [:]

        // Sweep extras
        let all = try decoder.container(keyedBy: AnyCodingKey.self)
        let known = Set(CodingKeys.allCases.map { $0.stringValue })
        var extras: [String: JSONValue] = [:]
        for key in all.allKeys where !known.contains(key.stringValue) {
            extras[key.stringValue] = try all.decode(JSONValue.self, forKey: key)
        }
        self.values = extras
    }


    // Encode known keys and then each entry in `values` at top level
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(filePath, forKey: .filePath)

        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(subtitle, forKey: .subtitle)
        try c.encode(isPublic, forKey: .isPublic)
        try c.encodeIfPresent(summary, forKey: .summary)
        try c.encodeIfPresent(domain, forKey: .domain)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(phase, forKey: .phase)
        try c.encodeIfPresent(featured, forKey: .featured)
        try c.encodeIfPresent(requiresFollowUp, forKey: .requiresFollowUp)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(assetsFolder, forKey: .assetsFolder)
        
        if !images.isEmpty { try c.encode(images, forKey: .images) }

        if !tags.isEmpty { try c.encode(tags, forKey: .tags) }
        if !mediums.isEmpty { try c.encode(mediums, forKey: .mediums) }
        if !genres.isEmpty { try c.encode(genres, forKey: .genres) }
        if !topics.isEmpty { try c.encode(topics, forKey: .topics) }
        if !subjects.isEmpty { try c.encode(subjects, forKey: .subjects) }

        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(story, forKey: .story)
        if !resources.isEmpty { try c.encode(resources, forKey: .resources) }
        if !collection.isEmpty { try c.encode(collection, forKey: .collection) }

        var dyn = encoder.container(keyedBy: AnyCodingKey.self)
        for (k, v) in values {
            try dyn.encode(v, forKey: AnyCodingKey(stringValue: k)!)
        }
    }
}

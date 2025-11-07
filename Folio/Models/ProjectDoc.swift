//
//  ProjectDoc.swift
//  Folio
//
//  Created by Zachary Sturman on 11/3/25.
//

import Foundation
import SwiftData

@Model
final class ProjectDoc {
    @Attribute(.unique) var id: UUID
    var title: String
    var filePath: String
    var updatedAt: Date
    
    var isPublic: Bool
    
    @Relationship(deleteRule: .nullify)
    var domain: ProjectDomain?
    
    @Relationship(deleteRule: .nullify)
    var category: ProjectCategory?
    
    @Relationship(deleteRule: .nullify)
    var status: ProjectStatus?
    
    @Relationship(deleteRule: .nullify)
    var phase: ProjectStatusPhase?
    
    @Relationship(deleteRule: .nullify)
     var tags: [ProjectTag] = []
    
    @Relationship(deleteRule: .nullify)
    var mediums: [ProjectMedium] = []
    
    @Relationship(deleteRule: .nullify)
    var genres: [ProjectGenre] = []
    
    @Relationship(deleteRule: .nullify)
    var topics: [ProjectTopic] = []
    
    @Relationship(deleteRule: .nullify)
    var subjects: [ProjectSubject] = []

    
    init(id: UUID, title: String, filePath: String, updatedAt: Date, isPublic: Bool = false, status: ProjectStatus?, phase: ProjectStatusPhase?, domain: ProjectDomain? = nil, category: ProjectCategory? = nil, tags: [ProjectTag], mediums: [ProjectMedium], genres: [ProjectGenre], topics: [ProjectTopic], subjects: [ProjectSubject]) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.updatedAt = updatedAt
        self.isPublic = isPublic
        self.status = status
        self.phase = phase
        self.domain = domain
        self.category = category
        self.tags = tags
        self.mediums = mediums
        self.genres = genres
        self.topics = topics
        self.subjects = subjects
    }
}


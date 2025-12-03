//
//  LauncherPermissionTests.swift
//  UnitTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import Testing
import Foundation
import SwiftData
@testable import Folio

// MARK: - Launcher Permission Handling Tests

@Suite("Launcher Permission Handling Tests")
struct LauncherPermissionHandlingTests {
    
    @Test("File exists check works correctly")
    func testFileExistsCheck() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test-\(UUID().uuidString).txt")
        
        // File doesn't exist yet
        #expect(!FileManager.default.fileExists(atPath: testFile.path))
        
        // Create file
        try? "test content".write(to: testFile, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: testFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
        #expect(!FileManager.default.fileExists(atPath: testFile.path))
    }
    
    @Test("Readable file check works correctly")
    func testReadableFileCheck() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("readable-\(UUID().uuidString).txt")
        
        // Create file
        try? "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // File should be readable
        #expect(FileManager.default.isReadableFile(atPath: testFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    @Test("Non-existent file is not readable")
    func testNonExistentFileNotReadable() {
        let nonExistentPath = "/path/that/does/not/exist/file.txt"
        
        #expect(!FileManager.default.fileExists(atPath: nonExistentPath))
        #expect(!FileManager.default.isReadableFile(atPath: nonExistentPath))
    }
}

// MARK: - ProjectDoc File Path Tests

@Suite("ProjectDoc File Path Tests")
struct ProjectDocFilePathTests {
    
    @Test("ProjectDoc stores file path correctly")
    func testProjectDocFilePath() async throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let testPath = "/Users/test/Documents/MyProject.folioDoc"
        
        let doc = ProjectDoc(
            id: UUID(),
            title: "Test Project",
            filePath: testPath,
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        context.insert(doc)
        try context.save()
        
        #expect(doc.filePath == testPath)
    }
    
    @Test("ProjectDoc file path can be updated")
    func testProjectDocFilePathUpdate() async throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let originalPath = "/Users/test/Documents/Original.folioDoc"
        let newPath = "/Users/test/Documents/Relocated.folioDoc"
        
        let doc = ProjectDoc(
            id: UUID(),
            title: "Relocatable Project",
            filePath: originalPath,
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        context.insert(doc)
        try context.save()
        
        #expect(doc.filePath == originalPath)
        
        // Update path
        doc.filePath = newPath
        try context.save()
        
        #expect(doc.filePath == newPath)
    }
    
    @Test("Multiple ProjectDocs with different paths")
    func testMultipleProjectDocsWithPaths() async throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let paths = [
            "/Users/test/Documents/Project1.folioDoc",
            "/Users/test/Documents/Project2.folioDoc",
            "/Users/test/Documents/Project3.folioDoc"
        ]
        
        for (index, path) in paths.enumerated() {
            let doc = ProjectDoc(
                id: UUID(),
                title: "Project \(index + 1)",
                filePath: path,
                updatedAt: Date(),
                isPublic: true,
                status: nil,
                phase: nil,
                domain: nil,
                category: nil,
                tags: [],
                mediums: [],
                genres: [],
                topics: [],
                subjects: []
            )
            context.insert(doc)
        }
        
        try context.save()
        
        let fd = FetchDescriptor<ProjectDoc>(sortBy: [SortDescriptor(\.title)])
        let docs = try context.fetch(fd)
        
        #expect(docs.count == 3)
        for (index, doc) in docs.enumerated() {
            #expect(doc.filePath == paths[index])
        }
    }
}

// MARK: - Recent Documents Query Tests

@Suite("Recent Documents Query Tests")
struct RecentDocumentsQueryTests {
    
    @Test("Documents sorted by updatedAt descending")
    func testDocumentsSortedByUpdatedAt() async throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-604800)
        
        let recentDoc = ProjectDoc(
            id: UUID(),
            title: "Recent",
            filePath: "/recent.folioDoc",
            updatedAt: now,
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        let oldDoc = ProjectDoc(
            id: UUID(),
            title: "Old",
            filePath: "/old.folioDoc",
            updatedAt: lastWeek,
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        let middleDoc = ProjectDoc(
            id: UUID(),
            title: "Middle",
            filePath: "/middle.folioDoc",
            updatedAt: yesterday,
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        // Insert in random order
        context.insert(middleDoc)
        context.insert(recentDoc)
        context.insert(oldDoc)
        try context.save()
        
        // Query sorted by updatedAt descending
        let fd = FetchDescriptor<ProjectDoc>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let docs = try context.fetch(fd)
        
        #expect(docs.count == 3)
        #expect(docs[0].title == "Recent")
        #expect(docs[1].title == "Middle")
        #expect(docs[2].title == "Old")
    }
    
    @Test("Query limited to first 8 documents")
    func testQueryLimitedTo8Documents() async throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        // Create 12 documents
        for i in 0..<12 {
            let date = Date().addingTimeInterval(Double(i))
            let doc = ProjectDoc(
                id: UUID(),
                title: "Project \(i)",
                filePath: "/project\(i).folioDoc",
                updatedAt: date,
                isPublic: true,
                status: nil,
                phase: nil,
                domain: nil,
                category: nil,
                tags: [],
                mediums: [],
                genres: [],
                topics: [],
                subjects: []
            )
            context.insert(doc)
        }
        try context.save()
        
        let fd = FetchDescriptor<ProjectDoc>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let allDocs = try context.fetch(fd)
        
        // Launcher shows first 8 (prefix(8))
        let displayedDocs = Array(allDocs.prefix(8))
        
        #expect(allDocs.count == 12)
        #expect(displayedDocs.count == 8)
    }
}

// MARK: - File Permission State Tests

@Suite("File Permission State Tests")
struct FilePermissionStateTests {
    
    @Test("File exists and is readable - no permission needed")
    func testFileExistsAndReadable() {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("readable-\(UUID().uuidString).txt")
        
        // Create file
        try? "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        let fileExists = FileManager.default.fileExists(atPath: testFile.path)
        let isReadable = FileManager.default.isReadableFile(atPath: testFile.path)
        let needsPermission = fileExists && !isReadable
        
        #expect(fileExists == true)
        #expect(isReadable == true)
        #expect(needsPermission == false)
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    @Test("File does not exist - show missing indicator")
    func testFileMissing() {
        let missingPath = "/path/to/missing/file.txt"
        
        let fileExists = FileManager.default.fileExists(atPath: missingPath)
        let isReadable = FileManager.default.isReadableFile(atPath: missingPath)
        
        #expect(fileExists == false)
        #expect(isReadable == false)
    }
}

// MARK: - Document Removal Tests

@Suite("Document Removal from List Tests")
struct DocumentRemovalTests {
    
    @Test("Document can be removed from context")
    func testDocumentRemoval() async throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let doc = ProjectDoc(
            id: UUID(),
            title: "To Be Removed",
            filePath: "/remove.folioDoc",
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        context.insert(doc)
        try context.save()
        
        let fd1 = FetchDescriptor<ProjectDoc>()
        let docs1 = try context.fetch(fd1)
        #expect(docs1.count == 1)
        
        // Remove document
        context.delete(doc)
        try context.save()
        
        let fd2 = FetchDescriptor<ProjectDoc>()
        let docs2 = try context.fetch(fd2)
        #expect(docs2.count == 0)
    }
    
    @Test("Removing document does not affect others")
    func testRemoveOneDocumentKeepsOthers() async throws {
        let schema = Schema([ProjectDoc.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let doc1 = ProjectDoc(
            id: UUID(),
            title: "Keep This",
            filePath: "/keep.folioDoc",
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        let doc2 = ProjectDoc(
            id: UUID(),
            title: "Remove This",
            filePath: "/remove.folioDoc",
            updatedAt: Date(),
            isPublic: true,
            status: nil,
            phase: nil,
            domain: nil,
            category: nil,
            tags: [],
            mediums: [],
            genres: [],
            topics: [],
            subjects: []
        )
        
        context.insert(doc1)
        context.insert(doc2)
        try context.save()
        
        // Remove doc2
        context.delete(doc2)
        try context.save()
        
        let fd = FetchDescriptor<ProjectDoc>()
        let docs = try context.fetch(fd)
        
        #expect(docs.count == 1)
        #expect(docs[0].title == "Keep This")
    }
}


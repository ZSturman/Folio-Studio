//
//  SwiftDataCoordinatorFixes.swift
//  Folio
//
//  Created by Zachary Sturman on 11/17/25.
//
//  CRITICAL FIX: Address race condition in upsert operations
//

import Foundation
import SwiftData

/*
 CRITICAL ISSUE IDENTIFIED: Race Condition in Upsert Operations
 
 Problem:
 --------
 The current upsert pattern in SwiftDataCoordinator has a TOCTOU (time-of-check-to-time-of-use) race condition:
 
 1. Thread A checks if "swift" tag exists -> not found
 2. Thread B checks if "swift" tag exists -> not found
 3. Thread A creates new "swift" tag and inserts
 4. Thread B creates new "swift" tag and inserts
 5. Result: Two "swift" tags in database (one becomes "swift-2")
 
 This happens when:
 - Multiple documents are opened simultaneously and both have the same tag
 - User rapidly adds same tag to multiple documents
 - SwiftData sync occurs before debounce timer fires
 
 Current Code Pattern (UNSAFE):
 -------------------------------
 private func upsertTag(name: String, in context: ModelContext) throws -> ProjectTag {
     if let existing = try fetchTag(slug: name.slugified(), in: context) {
         return existing  // ← Gap here allows race
     }
     let created = try ProjectTag(name: name, in: context)  // ← Both threads reach here
     context.insert(created)
     return created
 }
 
 Solution Options:
 -----------------
 
 Option 1: Pessimistic Locking (RECOMMENDED)
 Add a serial queue per taxonomy type to serialize upsert operations:
 
 actor TaxonomyLock {
     private var locks: [String: NSLock] = [:]
     
     func withLock<T>(for key: String, work: () throws -> T) rethrows -> T {
         let lock = locks[key] ?? NSLock()
         locks[key] = lock
         lock.lock()
         defer { lock.unlock() }
         return try work()
     }
 }
 
 Option 2: Optimistic Locking
 Catch uniqueness violations and retry:
 
 private func upsertTag(name: String, in context: ModelContext) throws -> ProjectTag {
     do {
         let created = try ProjectTag(name: name, in: context)
         context.insert(created)
         try context.save()  // Force immediate save to trigger uniqueness check
         return created
     } catch {
         // If uniqueness violation, fetch and return existing
         if let existing = try fetchTag(slug: name.slugified(), in: context) {
             return existing
         }
         throw error
     }
 }
 
 Option 3: Database-Level Unique Constraint (IDEAL)
 SwiftData's @Attribute(.unique) should enforce this, but we need to ensure:
 - Constraint is properly configured
 - Error handling accounts for violations
 - Retries are in place
 
 Option 4: Single-Actor Serialization
 Move all taxonomy operations to a dedicated actor:
 
 actor TaxonomyManager {
     private let context: ModelContext
     
     func upsertTag(name: String) throws -> ProjectTag {
         // All operations serialized by actor
     }
 }
 
 Recommended Implementation:
 ---------------------------
 Use Option 1 (Pessimistic Locking) because:
 - Simplest to implement without major refactor
 - No retry logic needed
 - Works with existing code structure
 - Performance impact minimal (tags created infrequently)
 
 Alternative: Use Option 3 + retry logic for production robustness
 
 Testing Strategy:
 -----------------
 1. Unit test: Concurrent upsert of same tag from 10+ threads
 2. Integration test: Open 5 documents with shared tags simultaneously
 3. Stress test: Rapid add/remove cycles of same tag
 4. Verification: Query for duplicate slugs after tests
 
 Additional Recommendations:
 ---------------------------
 1. Add logging to detect when retries occur
 2. Add metrics/monitoring for duplicate detection
 3. Consider background job to cleanup any existing duplicates
 4. Document the locking strategy in code comments
 5. Add transaction boundaries around upsert + append operations
 */

// MARK: - Proposed Fix Implementation

extension SwiftDataCoordinator {
    
    // Add this lock structure at class level
    private static let upsertLock = NSLock()
    
    // Helper to access the private fetchTag method
    fileprivate func fetchTagInternal(slug: String, in context: ModelContext) throws -> ProjectTag? {
        let fd = FetchDescriptor<ProjectTag>(predicate: #Predicate { $0.slug == slug })
        return try context.fetch(fd).first
    }
    
    // Modified upsert with locking (example for ProjectTag)
    func upsertTagSafe(name: String, in context: ModelContext) throws -> ProjectTag {
        // Lock ensures only one thread can execute upsert at a time
        Self.upsertLock.lock()
        defer { Self.upsertLock.unlock() }
        
        // Double-check pattern: check again after acquiring lock
        if let existing = try self.fetchTagInternal(slug: name.slugified(), in: context) {
            print("[SDC] upsertTagSafe: found existing after lock")
            return existing
        }
        
        // Safe to create now - we hold the lock
        let created = try ProjectTag(name: name, in: context)
        context.insert(created)
        
        // Optional: Force immediate save to ensure uniqueness constraint is checked
        try context.save()
        
        print("[SDC] upsertTagSafe: created new")
        return created
    }
    
    // Alternative: Optimistic approach with retry
    func upsertTagOptimistic(name: String, in context: ModelContext) throws -> ProjectTag {
        // Try to create first
        let slug = name.slugified()
        
        // Attempt 1: Check if exists
        if let existing = try self.fetchTagInternal(slug: slug, in: context) {
            return existing
        }
        
        // Attempt 2: Try to create
        do {
            let created = try ProjectTag(name: name, in: context)
            context.insert(created)
            
            // Force save to trigger uniqueness constraint
            try context.save()
            return created
        } catch {
            // If failed (likely uniqueness violation), try fetching again
            if let existing = try self.fetchTagInternal(slug: slug, in: context) {
                print("[SDC] upsertTagOptimistic: recovered from race, found existing")
                return existing
            }
            
            // Unknown error
            throw error
        }
    }
}

/*
 VALIDATION ISSUES IDENTIFIED:
 
 1. Empty Title Validation
 --------------------------
 Issue: Documents can have empty titles
 Impact: Confusing in launcher, hard to identify documents
 Recommendation: 
   - Add validation: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
   - Default to "Untitled Project" if empty
   - Show warning in UI
 
 2. Circular Folio References
 ----------------------------
 Issue: Collection items of type .folio can reference each other circularly
 Impact: Infinite loops during traversal, stack overflow
 Recommendation:
   - Track visited UUIDs during traversal
   - Limit recursion depth to 10
   - Show warning in UI when circular reference detected
 
 3. URL Format Validation
 ------------------------
 Issue: No validation on resource URLs or collection item URLs
 Impact: Broken links, security risks
 Recommendation:
   - Validate URL format using URLComponents
   - Whitelist allowed schemes: http, https, file
   - Show validation error in UI
 
 4. File Path Validation
 -----------------------
 Issue: No validation on asset paths
 Impact: Invalid paths cause file operations to fail
 Recommendation:
   - Check for invalid characters: <, >, :, ", |, ?, *
   - Validate path is not absolute when it should be relative
   - Check path length doesn't exceed system limits (macOS: 1024)
 
 5. Crop Rectangle Bounds
 -------------------------
 Issue: Image editor doesn't validate crop rectangle is within image bounds
 Impact: Render failures, invalid transformations
 Recommendation:
   - Clamp crop rect to [0, 1] normalized coordinates
   - Ensure width and height are positive
   - Validate rect doesn't exceed image bounds after transforms
 
 IMPLEMENTATION PLAN:
 
 Phase 1 - Critical (Implement Now):
 - Fix upsert race condition
 - Add circular reference detection
 
 Phase 2 - Important (Next Sprint):
 - Add title validation
 - Add URL validation
 
 Phase 3 - Nice to Have:
 - File path validation
 - Crop bounds validation
 
 TESTING REQUIREMENTS:
 
 For Each Validation:
 1. Unit test: Valid input passes
 2. Unit test: Invalid input fails gracefully
 3. UI test: Error message displayed correctly
 4. Integration test: Validation doesn't break existing data
 */

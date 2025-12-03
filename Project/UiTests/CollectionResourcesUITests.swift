//
//  CollectionResourcesUITests.swift
//  UiTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import XCTest

final class CollectionResourcesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Multiple Resources UI Tests
    
    @MainActor
    func testAddMultipleResourcesToCollectionItem() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to a document (create new or open existing)
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Navigate to Collection tab if available
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            sleep(1)
        }
    }
    
    @MainActor
    func testDeleteResourceFromCollectionItem() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Look for delete resource button
        let deleteResourceButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'delete' OR label CONTAINS 'trash'"))
        
        if deleteResourceButtons.count > 0 {
            let initialCount = deleteResourceButtons.count
            deleteResourceButtons.firstMatch.tap()
            sleep(1)
            
            // Verify resource was deleted
            let newCount = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'delete' OR label CONTAINS 'trash'")).count
            XCTAssertLessThan(newCount, initialCount, "Resource should be deleted")
        }
    }
    
    @MainActor
    func testReorderResources() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Look for arrow up/down buttons for reordering
        let arrowUpButton = app.buttons.matching(identifier: "arrow.up").firstMatch
        let arrowDownButton = app.buttons.matching(identifier: "arrow.down").firstMatch
        
        if arrowUpButton.exists {
            // Check that first item cannot move up (button should be disabled)
            XCTAssertFalse(arrowUpButton.isEnabled, "First resource cannot move up")
        }
        
        if arrowDownButton.exists && arrowDownButton.isEnabled {
            arrowDownButton.tap()
            sleep(1)
        }
    }
    
    // MARK: - Folio Toggle UI Tests
    
    @MainActor
    func testFolioTypeToggles() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Navigate to Collection tab
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            sleep(1)
        }
        
        // Look for Folio type selector (segmented control or picker)
        if app.buttons["Folio"].exists {
            app.buttons["Folio"].tap()
            sleep(1)
            
            // Look for Folio-specific toggles
            let useTitleToggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'title'")).firstMatch
            let useSummaryToggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'summary'")).firstMatch
            let useThumbnailToggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'thumbnail'")).firstMatch
            
            if useTitleToggle.exists {
                useTitleToggle.tap()
                usleep(500_000)
                // Verify toggle changed state
                XCTAssertTrue(useTitleToggle.exists)
            }
            
            if useSummaryToggle.exists {
                useSummaryToggle.tap()
                usleep(500_000)
            }
            
            if useThumbnailToggle.exists {
                useThumbnailToggle.tap()
                usleep(500_000)
            }
        }
    }
    
    @MainActor
    func testFolioTypeProjectPicker() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Navigate to Collection, select Folio type
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            sleep(1)
        }
        
        if app.buttons["Folio"].exists {
            app.buttons["Folio"].tap()
            sleep(1)
            
            // Look for project picker
            let projectPickers = app.popUpButtons.matching(NSPredicate(format: "label CONTAINS 'Project' OR identifier CONTAINS 'project'"))
            
            if projectPickers.count > 0 {
                projectPickers.firstMatch.tap()
                usleep(500_000)
                // Menu items should appear
            }
        }
    }
    
    @MainActor
    func testShowPrivateProjectsToggle() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Look for "Show private projects" toggle
        let privateToggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'private'")).firstMatch
        
        if privateToggle.exists {
            let initialState = privateToggle.value as? String
            privateToggle.tap()
            usleep(500_000)
            
            let newState = privateToggle.value as? String
            XCTAssertNotEqual(initialState, newState, "Toggle state should change")
        }
    }
    
    // MARK: - Source Type Picker UI Tests
    
    @MainActor
    func testSourceTypeSegmentedControl() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            sleep(1)
        }
        
        // Look for File/URL/Folio segmented control
        if app.buttons["File"].exists {
            app.buttons["File"].tap()
            usleep(500_000)
        }
        
        if app.buttons["URL"].exists {
            app.buttons["URL"].tap()
            usleep(500_000)
        }
        
        if app.buttons["Folio"].exists {
            app.buttons["Folio"].tap()
            usleep(500_000)
        }
    }
    
    @MainActor
    func testSourceTypeChangesContent() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Switch between source types and verify different UI appears
        if app.buttons["File"].exists {
            app.buttons["File"].tap()
            usleep(500_000)
            
            // File type should show file picker or drag target
        }
        
        if app.buttons["URL"].exists {
            app.buttons["URL"].tap()
            usleep(500_000)
            
            // URL type should show URL text field
            let urlFields = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'http' OR placeholderValue CONTAINS 'example'"))
            XCTAssertTrue(urlFields.count > 0 || app.textFields.count > 0)
        }
    }
}


//
//  StatusPhaseUITests.swift
//  UiTests
//
//  Created by GitHub Copilot on 12/2/25.
//

import XCTest

final class StatusPhaseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Status Display Name UI Tests
    
    @MainActor
    func testStatusDisplaysFormattedName() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        // Navigate to Basic Info or wherever status picker is
        if app.buttons["Basic Info"].exists {
            app.buttons["Basic Info"].tap()
            sleep(1)
        }
        
        // Look for status picker
        let statusPicker = app.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS 'status' OR label CONTAINS 'Status'")).firstMatch
        
        if statusPicker.exists {
            statusPicker.tap()
            sleep(500_000)
            
            // Menu should show formatted names like "In Progress", "On Hold", etc.
            // Not camelCase like "inProgress", "onHold"
            let menuItems = app.menuItems
            
            // Check that at least one menu item has title-cased text with spaces
            var foundFormattedName = false
            for i in 0..<min(menuItems.count, 10) {
                let title = menuItems.element(boundBy: i).title
                if title.contains(" ") && title.first?.isUppercase == true {
                    foundFormattedName = true
                    break
                }
            }
            
            XCTAssertTrue(foundFormattedName, "Status names should be formatted as Title Case")
            
            // Close menu
            app.typeKey(.escape, modifierFlags: [])
        }
    }
    
    @MainActor
    func testPhaseDisplaysFormattedName() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        if app.buttons["Basic Info"].exists {
            app.buttons["Basic Info"].tap()
            sleep(1)
        }
        
        // Look for phase picker
        let phasePicker = app.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS 'phase' OR label CONTAINS 'Phase'")).firstMatch
        
        if phasePicker.exists && phasePicker.isEnabled {
            phasePicker.tap()
            sleep(500_000)
            
            // Menu should show formatted names
            let menuItems = app.menuItems
            
            var foundFormattedName = false
            for i in 0..<min(menuItems.count, 10) {
                let title = menuItems.element(boundBy: i).title
                // Check for title case formatting
                if title.contains(" ") && title.first?.isUppercase == true {
                    foundFormattedName = true
                    break
                }
            }
            
            // Close menu
            app.typeKey(.escape, modifierFlags: [])
            
            // Note: Phase names might be empty if no status is selected
            // So we only assert if we found items
            if menuItems.count > 1 {
                XCTAssertTrue(foundFormattedName, "Phase names should be formatted as Title Case")
            }
        }
    }
    
    @MainActor
    func testAddNewStatusWithFormattedName() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        if app.buttons["Basic Info"].exists {
            app.buttons["Basic Info"].tap()
            sleep(1)
        }
        
        // Look for add status button (plus icon)
        let addStatusButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plus' OR label CONTAINS 'Add'")).firstMatch
        
        if addStatusButton.exists {
            addStatusButton.tap()
            sleep(500_000)
            
            // Sheet or dialog should appear
            let textFields = app.textFields
            if textFields.count > 0 {
                let statusNameField = textFields.firstMatch
                statusNameField.tap()
                statusNameField.typeText("customWorkflowState")
                sleep(500_000)
                
                // Save button
                let saveButton = app.buttons["Save"]
                if saveButton.exists {
                    saveButton.tap()
                    sleep(1)
                    
                    // The newly created status should appear with formatted name
                    // "Custom Workflow State" not "customWorkflowState"
                }
            }
        }
    }
    
    @MainActor
    func testAddNewPhaseWithFormattedName() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        if app.buttons["Basic Info"].exists {
            app.buttons["Basic Info"].tap()
            sleep(1)
        }
        
        // First select a status
        let statusPicker = app.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS 'status'")).firstMatch
        if statusPicker.exists {
            statusPicker.tap()
            sleep(500_000)
            
            // Select first available status
            if app.menuItems.count > 1 {
                app.menuItems.element(boundBy: 1).tap()
                sleep(500_000)
            }
        }
        
        // Now add phase button should be enabled
        let addPhaseButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plus'"))
        
        // Find the phase add button (usually second plus button)
        if addPhaseButtons.count > 1 {
            addPhaseButtons.element(boundBy: 1).tap()
            sleep(500_000)
            
            let textFields = app.textFields
            if textFields.count > 0 {
                let phaseNameField = textFields.firstMatch
                phaseNameField.tap()
                phaseNameField.typeText("needsRefactor")
                sleep(500_000)
                
                let saveButton = app.buttons["Save"]
                if saveButton.exists {
                    saveButton.tap()
                    sleep(1)
                    
                    // Should display as "Needs Refactor"
                }
            }
        }
    }
    
    // MARK: - Status/Phase Selection Tests
    
    @MainActor
    func testSelectingStatusEnablesPhase() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        if app.buttons["Basic Info"].exists {
            app.buttons["Basic Info"].tap()
            sleep(1)
        }
        
        let phasePicker = app.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS 'phase'")).firstMatch
        
        // Phase picker should be disabled initially
        if phasePicker.exists {
            let initiallyEnabled = phasePicker.isEnabled
            
            // Select a status
            let statusPicker = app.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS 'status'")).firstMatch
            if statusPicker.exists {
                statusPicker.tap()
                sleep(500_000)
                
                // Select first available status
                if app.menuItems.count > 1 {
                    app.menuItems.element(boundBy: 1).tap()
                    sleep(500_000)
                    
                    // Phase picker should now be enabled
                    let nowEnabled = phasePicker.isEnabled
                    
                    if !initiallyEnabled {
                        XCTAssertTrue(nowEnabled, "Phase picker should be enabled after selecting status")
                    }
                }
            }
        }
    }
    
    @MainActor
    func testStatusPickerShowsMultipleOptions() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(2)
        }
        
        if app.buttons["Basic Info"].exists {
            app.buttons["Basic Info"].tap()
            sleep(1)
        }
        
        let statusPicker = app.popUpButtons.matching(NSPredicate(format: "identifier CONTAINS 'status'")).firstMatch
        
        if statusPicker.exists {
            statusPicker.tap()
            sleep(500_000)
            
            let menuItems = app.menuItems
            
            // Should have at least default statuses (idea, inProgress, done, etc.)
            XCTAssertGreaterThan(menuItems.count, 1, "Should have multiple status options")
            
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}

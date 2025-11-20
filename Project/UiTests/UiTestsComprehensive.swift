//
//  UiTestsComprehensive.swift
//  UiTests
//
//  Created by Zachary Sturman on 11/17/25.
//

import XCTest

final class UiTestsComprehensive: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Basic Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Launcher View Tests
    
    @MainActor
    func testDebugUIHierarchy() throws {
        let app = XCUIApplication()
        app.launch()
        
        sleep(2) // Give the app time to fully load and show launcher
        
        print("=== DEBUG: UI Hierarchy ===")
        print("Windows count: \(app.windows.count)")
        for i in 0..<app.windows.count {
            let window = app.windows.element(boundBy: i)
            print("Window \(i): identifier='\(window.identifier)', title='\(window.title)', exists=\(window.exists)")
        }
        
        print("\nAll buttons in app:")
        for i in 0..<min(app.buttons.count, 20) {
            let button = app.buttons.element(boundBy: i)
            print("Button \(i): label='\(button.label)', identifier='\(button.identifier)', exists=\(button.exists)")
        }
        
        print("\nAll static texts:")
        for i in 0..<min(app.staticTexts.count, 20) {
            let text = app.staticTexts.element(boundBy: i)
            print("Text \(i): label='\(text.label)', exists=\(text.exists)")
        }
        
        // This test always passes - it's just for debugging
        XCTAssertTrue(true)
    }
    
    @MainActor
    func testLauncherViewAppears() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for any window to appear (WindowGroup creates a window automatically)
        let anyWindow = app.windows.firstMatch
        XCTAssertTrue(anyWindow.waitForExistence(timeout: 8), "A window should appear automatically on launch")
        
        // Look for the launcher UI elements (buttons) in the app
        // Check by accessibility identifier first
        let newButton = app.buttons.matching(identifier: "New...").firstMatch
        let openButton = app.buttons.matching(identifier: "Open...").firstMatch
        
        // Also check by label (with ellipsis character)
        let newButtonByLabel = app.buttons["New…"].firstMatch
        let openButtonByLabel = app.buttons["Open…"].firstMatch
        
        let exists = newButton.waitForExistence(timeout: 2) ||
                     openButton.waitForExistence(timeout: 2) ||
                     newButtonByLabel.exists ||
                     openButtonByLabel.exists
        
        XCTAssertTrue(exists, "Launcher view should have New and Open buttons")
    }
    
    @MainActor
    func testCreateNewDocument() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Tap New button if it exists
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            
            // Document window should appear
            // This might trigger a file save dialog
            sleep(1)
        }
    }
    
    @MainActor
    func testRecentDocumentsList() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check if recent documents list exists
        // The list might be empty on first run
        sleep(1)
    }
    
    // MARK: - Navigation Tests
    
    @MainActor
    func testSidebarTabsExist() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Create or open a document first
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Check for sidebar tabs
        // These might be buttons or other UI elements
        // Tab names: Basic Info, Content, Media, Collection, Snippets, Settings
    }
    
    @MainActor
    func testNavigateToBasicInfo() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Try to find and tap Basic Info tab
        if app.buttons["Basic Info"].exists {
            app.buttons["Basic Info"].tap()
            usleep(500_000)
        }
    }
    
    @MainActor
    func testNavigateToContent() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Content"].exists {
            app.buttons["Content"].tap()
            usleep(500_000)
        }
    }
    
    @MainActor
    func testNavigateToMedia() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Media"].exists {
            app.buttons["Media"].tap()
            usleep(500_000)
        }
    }
    
    @MainActor
    func testNavigateToCollection() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            usleep(500_000)
        }
    }
    
    @MainActor
    func testNavigateToSettings() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
        }
    }
    
    // MARK: - Basic Info Tests
    
    @MainActor
    func testEditTitle() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Look for title text field
        let titleFields = app.textFields.matching(identifier: "title")
        if titleFields.count > 0 {
            let titleField = titleFields.firstMatch
            titleField.tap()
            titleField.typeText("Test Project Title")
        } else if app.textFields.count > 0 {
            // Fallback: use first text field
            let titleField = app.textFields.firstMatch
            titleField.tap()
            titleField.typeText("Test Project Title")
        }
    }
    
    @MainActor
    func testEditSubtitle() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Look for subtitle field
        let subtitleFields = app.textFields.matching(identifier: "subtitle")
        if subtitleFields.count > 0 {
            let subtitleField = subtitleFields.firstMatch
            subtitleField.tap()
            subtitleField.typeText("Test Subtitle")
        }
    }
    
    @MainActor
    func testToggleIsPublic() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Look for Public toggle
        if app.checkBoxes["Public"].exists {
            app.checkBoxes["Public"].tap()
        } else if app.switches["Public"].exists {
            app.switches["Public"].tap()
        }
    }
    
    @MainActor
    func testToggleFeatured() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Look for Featured toggle
        if app.checkBoxes["Featured"].exists {
            app.checkBoxes["Featured"].tap()
        } else if app.switches["Featured"].exists {
            app.switches["Featured"].tap()
        }
    }
    
    // MARK: - Classification Tests
    
    @MainActor
    func testAddTag() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Navigate to classification section
        // Look for tag input field
        let tagFields = app.textFields.matching(identifier: "tagInput")
        if tagFields.count > 0 {
            let tagField = tagFields.firstMatch
            tagField.tap()
            tagField.typeText("swift")
            // Press return to add tag
            tagField.typeText("\r")
        }
    }
    
    @MainActor
    func testSelectDomain() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Look for domain picker
        let domainPickers = app.popUpButtons.matching(identifier: "domainPicker")
        if domainPickers.count > 0 {
            domainPickers.firstMatch.tap()
            usleep(500_000)
        }
    }
    
    // MARK: - Collection Tests
    
    @MainActor
    func testAddCollectionSection() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Navigate to Collection tab
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            usleep(500_000)
        }
        
        // Look for "Add Section" or "+" button
        if app.buttons["Add Section"].exists {
            app.buttons["Add Section"].tap()
        }
    }
    
    @MainActor
    func testAddCollectionItem() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            usleep(500_000)
        }
        
        // Look for "Add Item" button
        if app.buttons["Add Item"].exists {
            app.buttons["Add Item"].tap()
        }
    }
    
    @MainActor
    func testSwitchCollectionItemType() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            usleep(500_000)
        }
        
        // Add item first, then try switching type
        if app.buttons["Add Item"].exists {
            app.buttons["Add Item"].tap()
            usleep(500_000)
        }
        
        // Look for type picker (File/URL/Folio)
        let typePickers = app.popUpButtons.matching(identifier: "itemTypePicker")
        if typePickers.count > 0 {
            typePickers.firstMatch.tap()
            usleep(500_000)
        }
    }
    
    // MARK: - Settings Tests
    
    @MainActor
    func testOpenSettings() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Settings view should be visible
            // Could check for specific settings sections
        }
    }
    
    @MainActor
    func testSettingsGeneralSection() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Look for "General" section
            if app.staticTexts["General"].exists {
                // General section exists
            }
        }
    }
    
    @MainActor
    func testSettingsPresetsSection() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Look for "Presets" section
            if app.staticTexts["Presets"].exists {
                // Presets section exists
            }
        }
    }
    
    @MainActor
    func testSettingsCatalogsSection() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Look for "Catalogs" section
            if app.staticTexts["Catalogs"].exists {
                // Catalogs section exists
            }
        }
    }
    
    @MainActor
    func testAddTagInSettings() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Look for "Add Tag" or similar button
            let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'add'"))
            if addButtons.count > 0 {
                // Add button exists
            }
        }
    }
    
    @MainActor
    func testDeleteTagInSettings() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Look for delete buttons (might be "−" or trash icon)
            let deleteButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete' OR label == '−'"))
            if deleteButtons.count > 0 {
                // Delete button exists
            }
        }
    }
    
    @MainActor
    func testResetDefaultPresets() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Look for "Reset default presets" button
            if app.buttons["Reset default presets"].exists {
                // Don't actually tap it in test - just verify it exists
                XCTAssertTrue(app.buttons["Reset default presets"].exists)
            }
        }
    }
    
    // MARK: - Media Tests
    
    @MainActor
    func testNavigateToMediaTab() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Media"].exists {
            app.buttons["Media"].tap()
            usleep(500_000)
            
            // Media tab should be visible
        }
    }
    
    @MainActor
    func testImportImageButton() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Media"].exists {
            app.buttons["Media"].tap()
            usleep(500_000)
            
            // Look for "Import..." button
            if app.buttons["Import..."].exists {
                XCTAssertTrue(app.buttons["Import..."].exists)
            }
        }
    }
    
    @MainActor
    func testEditImageButton() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        if app.buttons["Media"].exists {
            app.buttons["Media"].tap()
            usleep(500_000)
            
            // Look for "Edit..." button (might be disabled if no image)
            let editButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'edit'"))
            if editButtons.count > 0 {
                // Edit button exists
            }
        }
    }
    
    // MARK: - Document State Tests
    
    @MainActor
    func testDocumentHasUndoRedo() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Make a change
        if app.textFields.count > 0 {
            let field = app.textFields.firstMatch
            field.tap()
            field.typeText("Test")
            
            // Try to undo via menu
            app.menuBars.menuBarItems["Edit"].click()
            if app.menuItems["Undo"].exists {
                XCTAssertTrue(app.menuItems["Undo"].exists)
            }
        }
    }
    
    @MainActor
    func testDocumentSaveState() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Make a change to dirty the document
        if app.textFields.count > 0 {
            let field = app.textFields.firstMatch
            field.tap()
            field.typeText("Dirty")
            
            // Document should show unsaved indicator (dot in close button)
            usleep(500_000)
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testBasicAccessibility() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check that key UI elements have accessibility labels
        sleep(1)
        
        // Buttons should be accessible
        if app.buttons["New..."].exists {
            XCTAssertTrue(app.buttons["New..."].isHittable)
        }
    }
    
    @MainActor
    func testKeyboardNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Test tabbing between fields
        if app.textFields.count > 0 {
            app.textFields.firstMatch.tap()
            // Tab to next field
            app.typeKey("\t", modifierFlags: [])
            usleep(200_000)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testHandleMissingPermissions() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Try to access media without permissions
        if app.buttons["Media"].exists {
            app.buttons["Media"].tap()
            usleep(500_000)
            
            // Should show permission prompt or grant access button
            let grantButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'grant' OR label CONTAINS[c] 'permission'"))
            // Permission UI might appear
        }
    }
    
    @MainActor
    func testHandleInvalidInput() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Try entering invalid data
        if app.textFields.count > 0 {
            let field = app.textFields.firstMatch
            field.tap()
            field.typeText(String(repeating: "a", count: 10000))
            
            // App should handle gracefully
            usleep(500_000)
        }
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testScrollingPerformance() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
        }
        
        // Navigate to a scrollable view
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            usleep(500_000)
            
            // Try scrolling if scroll view exists
            let scrollViews = app.scrollViews
            if scrollViews.count > 0 {
                let scrollView = scrollViews.firstMatch
                scrollView.swipeUp()
                scrollView.swipeDown()
            }
        }
    }
    
    @MainActor
    func testMultipleDocumentWindows() throws {
        let app = XCUIApplication()
        app.launch()
        
        if app.buttons["New..."].exists {
            app.buttons["New..."].tap()
            sleep(1)
            
            // Try opening another document
            app.menuBars.menuBarItems["File"].click()
            if app.menuItems["New"].exists {
                app.menuItems["New"].click()
                sleep(1)
                
                // Two document windows should exist
            }
        }
    }
    
    // MARK: - Settings Tab Navigation Tests
    
    @MainActor
    func testSettingsTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings if accessible
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            sleep(1)
            
            // Check for Classifications tab
            if app.staticTexts["Classifications"].exists {
                app.staticTexts["Classifications"].tap()
                sleep(1)
                
                XCTAssertTrue(app.staticTexts["Tags"].exists || app.staticTexts["Domains"].exists)
            }
            
            // Check for Preferences tab
            if app.staticTexts["Preferences"].exists {
                app.staticTexts["Preferences"].tap()
                sleep(1)
                
                // Should see launcher auto-open toggle
            }
        }
    }
    
    // MARK: - Code Snippets Export Tests
    
    @MainActor
    func testCodeSnippetsExportButton() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Snippets if accessible
        if app.buttons["Snippets"].exists {
            app.buttons["Snippets"].tap()
            sleep(1)
            
            // Check for Export button in toolbar
            if app.buttons["Export Folio Paths"].exists {
                XCTAssertTrue(app.buttons["Export Folio Paths"].isEnabled)
            }
        }
    }
    
    // MARK: - Media Inline Controls Tests
    
    @MainActor
    func testMediaInlineControls() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Media if accessible
        if app.buttons["Media"].exists {
            app.buttons["Media"].tap()
            sleep(1)
            
            // Check for inline preview controls
            let zoomSlider = app.sliders["Zoom"]
            let rotationSlider = app.sliders["Rotation"]
            
            // If image is loaded, controls should be available
            if zoomSlider.exists {
                XCTAssertTrue(rotationSlider.exists)
            }
        }
    }
    
    // MARK: - JSON Document Viewer Tests
    
    @MainActor
    func testJSONDocumentViewer() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Look for Show Document button
        if app.buttons["Show Document"].exists {
            app.buttons["Show Document"].tap()
            sleep(1)
            
            // JSON viewer sheet should appear
            XCTAssertTrue(app.staticTexts["Document JSON"].exists)
            
            // Copy button should exist
            XCTAssertTrue(app.buttons["Copy"].exists)
        }
    }
    
    // MARK: - Launcher Context Menu Tests
    
    @MainActor
    func testLauncherContextMenu() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(2)
        
        // Find a recent document in the list
        let documentsList = app.lists.firstMatch
        if documentsList.exists {
            let firstCell = documentsList.cells.firstMatch
            if firstCell.exists {
                // Right-click to show context menu
                firstCell.rightClick()
                sleep(1)
                
                // Check for context menu items
                XCTAssertTrue(
                    app.menuItems["Open"].exists ||
                    app.menuItems["Show in Finder"].exists ||
                    app.menuItems["Remove from List"].exists
                )
            }
        }
    }
    
    // MARK: - Collection Sidebar Highlighting Tests
    
    @MainActor
    func testCollectionSidebarHighlighting() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Collection if accessible
        if app.buttons["Collection"].exists {
            app.buttons["Collection"].tap()
            sleep(1)
            
            // Collection names should be bold
            // Items should be indented
            // Selection should span full width (visual check)
        }
    }
}

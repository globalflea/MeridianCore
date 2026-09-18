//
// MeridianMarkdownInteractiveUITests.swift
// MeridianUITests
//
// Comprehensive interactive UI test suite exercising user workflows in MeridianMarkdownEditor.
//

import Testing
import SwiftUI
import AppKit
@testable import MeridianUI
@testable import MeridianMarkdownDemo

@Suite("MeridianMarkdownEditor Interactive UI Workflows")
struct MeridianMarkdownInteractiveUITests {

    @Test("Interactive workflow: Typing heading and pressing Enter creates paragraph")
    @MainActor
    func testTypingHeadingAndEnter() throws {
        let document = MeridianMarkdownDocument(initialMarkdown: "")
        #expect(document.blocks.count == 1)

        let firstBlockID = document.blocks[0].id
        document.activateBlock(firstBlockID)
        #expect(document.activeBlockId == firstBlockID)

        // User types H1 markdown
        document.updateBlock(id: firstBlockID, newRawText: "# First Chapter")
        guard case .header(let level) = document.blocks[0].kind else {
            Issue.record("Expected block to be recognized as header")
            return
        }
        #expect(level == 1)

        // User hits Enter
        document.handleEnter(at: firstBlockID)
        #expect(document.blocks.count == 2)
        #expect(document.blocks[1].rawText == "")
        #expect(document.blocks[1].kind == .paragraph)
        #expect(document.activeBlockId == document.blocks[1].id)
    }

    @Test("Interactive workflow: Bullet list typing, Enter continuation, and Backspace escape")
    @MainActor
    func testBulletListWorkflow() throws {
        let document = MeridianMarkdownDocument(initialMarkdown: "")
        let firstID = document.blocks[0].id
        document.activateBlock(firstID)

        // 1. User types bullet item
        document.updateBlock(id: firstID, newRawText: "- Buy coffee")
        guard case .bulletList = document.blocks[0].kind else {
            Issue.record("Expected bullet list item")
            return
        }

        // 2. User presses Enter -> auto-continues list
        document.handleEnter(at: firstID)
        #expect(document.blocks.count == 2)
        #expect(document.blocks[1].rawText == "- ")
        let secondID = document.blocks[1].id
        #expect(document.activeBlockId == secondID)

        // 3. User types second item
        document.updateBlock(id: secondID, newRawText: "- Roast beans")

        // 4. User presses Enter again -> auto-continues list with empty bullet
        document.handleEnter(at: secondID)
        #expect(document.blocks.count == 3)
        #expect(document.blocks[2].rawText == "- ")
        let thirdID = document.blocks[2].id

        // 5. User presses Enter on empty bullet -> exits list and reverts to paragraph
        document.handleEnter(at: thirdID)
        #expect(document.blocks.count == 3)
        #expect(document.blocks[2].rawText == "")
        #expect(document.blocks[2].kind == .paragraph)
    }

    @Test("Interactive workflow: Numbered list auto-incrementing and backspace escape")
    @MainActor
    func testNumberedListWorkflow() throws {
        let document = MeridianMarkdownDocument(initialMarkdown: "1. Item one")
        let firstID = document.blocks[0].id
        document.activateBlock(firstID)

        // User hits Enter on '1. Item one' -> creates '2. '
        document.handleEnter(at: firstID)
        #expect(document.blocks.count == 2)
        #expect(document.blocks[1].rawText == "2. ")
        let secondID = document.blocks[1].id

        // User hits Backspace on empty '2. ' -> reverts to paragraph
        document.handleBackspace(at: secondID)
        #expect(document.blocks[1].rawText == "")
        #expect(document.blocks[1].kind == .paragraph)
    }

    @Test("Interactive workflow: Task checkbox click toggles state and persists to markdown")
    @MainActor
    func testTaskCheckboxToggleWorkflow() throws {
        let document = MeridianMarkdownDocument(initialMarkdown: "- [ ] Pending item")
        let blockID = document.blocks[0].id

        guard case .taskList(let isChecked, _) = document.blocks[0].kind else {
            Issue.record("Expected task list block")
            return
        }
        #expect(!isChecked)

        // User clicks the checkbox
        document.toggleTask(blockId: blockID)
        guard case .taskList(let updatedChecked, _) = document.blocks[0].kind else {
            Issue.record("Expected task list block after toggle")
            return
        }
        #expect(updatedChecked)
        #expect(document.blocks[0].rawText == "- [x] Pending item")

        // User clicks again to uncheck
        document.toggleTask(blockId: blockID)
        guard case .taskList(let rechecked, _) = document.blocks[0].kind else {
            Issue.record("Expected task list block after second toggle")
            return
        }
        #expect(!rechecked)
        #expect(document.blocks[0].rawText == "- [ ] Pending item")
    }

    @Test("Interactive workflow: Table row append on Enter key")
    @MainActor
    func testTableRowAppendOnEnter() throws {
        let markdown = """
        | Col A | Col B |
        | :--- | ---: |
        | Val 1 | Val 2 |
        """
        let document = MeridianMarkdownDocument(initialMarkdown: markdown)
        #expect(document.blocks.count == 1)

        let tableID = document.blocks[0].id
        document.activateBlock(tableID)

        // User presses Enter while focused on table
        document.handleEnter(at: tableID)

        guard case .table(let tableData) = document.blocks[0].kind else {
            Issue.record("Expected table block kind")
            return
        }
        #expect(tableData.rows.count == 2)
        #expect(document.blocks[0].rawText.contains("|  |  |"))
    }

    @Test("Interactive workflow: Theme toggling updates styling tokens")
    @MainActor
    func testThemeSwitching() throws {
        let document = MeridianMarkdownDocument(initialMarkdown: "# Test Theme", theme: .sepia)
        #expect(document.theme.isSerif == true)

        // Switch to Dark
        document.theme = .dark
        #expect(document.theme.isSerif == false)

        // Switch to Light
        document.theme = .light
        #expect(document.theme.isSerif == false)
    }

    @Test("Interactive view rendering: MeridianMarkdownDemoContentView renders to image without error")
    @MainActor
    func testDemoViewRendering() throws {
        let demoView = MeridianMarkdownDemoContentView()
            .frame(width: 900, height: 700)

        let renderer = ImageRenderer(content: demoView)
        renderer.scale = 2.0
        let image = renderer.nsImage
        #expect(image != nil)
        #expect(image?.size.width ?? 0 > 0)
    }
}

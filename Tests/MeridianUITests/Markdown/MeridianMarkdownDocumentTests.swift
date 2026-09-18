//
// MeridianMarkdownDocumentTests.swift
// MeridianUITests
//
// High-coverage unit test suite for MeridianMarkdownDocument and editing extensions
// verifying state management, smart list continuation, task toggles, and analytics.
//

import Testing
import Foundation
@testable import MeridianUI

@Suite("MeridianMarkdownDocument Tests")
struct MeridianMarkdownDocumentTests {

    @Test("Document initialization and analytics calculation")
    @MainActor
    func testDocumentInitAndAnalytics() {
        let initial = """
        # My Document
        This is a live test document.
        - First bullet point
        """
        let doc = MeridianMarkdownDocument(title: "Design Notes", initialMarkdown: initial, theme: .sepia)

        #expect(doc.title == "Design Notes")
        #expect(doc.theme == .sepia)
        #expect(doc.blocks.count == 3)
        #expect(doc.isLivePreviewEnabled == true)
        #expect(doc.isReadOnly == false)

        // Word and character count
        #expect(doc.wordCount > 5)
        #expect(doc.characterCount > 20)
    }

    @Test("Enter on non-empty bullet list continues the bullet list")
    @MainActor
    func testEnterContinuesBulletList() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "- First bullet")
        let firstId = doc.blocks[0].id

        doc.handleEnter(at: firstId)

        #expect(doc.blocks.count == 2)
        #expect(doc.blocks[0].rawText == "- First bullet")
        #expect(doc.blocks[1].rawText == "- ")
        #expect(doc.blocks[1].kind == .bulletList(indent: 0))
        #expect(doc.activeBlockId == doc.blocks[1].id)
    }

    @Test("Enter on empty bullet list exits the list and reverts to paragraph")
    @MainActor
    func testEnterOnEmptyBulletExitsList() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "- ")
        let firstId = doc.blocks[0].id

        doc.handleEnter(at: firstId)

        #expect(doc.blocks.count == 1)
        #expect(doc.blocks[0].kind == .paragraph)
        #expect(doc.blocks[0].rawText == "")
    }

    @Test("Enter on numbered list auto-increments the numeric index")
    @MainActor
    func testEnterAutoIncrementsNumberedList() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "1. Step One")
        let firstId = doc.blocks[0].id

        doc.handleEnter(at: firstId)

        #expect(doc.blocks.count == 2)
        #expect(doc.blocks[0].rawText == "1. Step One")
        #expect(doc.blocks[1].rawText == "2. ")
        #expect(doc.blocks[1].kind == .numberedList(index: 2, indent: 0))
        #expect(doc.activeBlockId == doc.blocks[1].id)

        // Hitting enter on empty "2." terminates the list
        doc.handleEnter(at: doc.blocks[1].id)
        #expect(doc.blocks.count == 2)
        #expect(doc.blocks[1].kind == .paragraph)
        #expect(doc.blocks[1].rawText == "")
    }

    @Test("Enter on task list continues task and toggles checkbox")
    @MainActor
    func testTaskListBehavior() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "- [ ] Task Item")
        let firstId = doc.blocks[0].id

        // Toggle task to completed
        doc.toggleTask(blockId: firstId)
        #expect(doc.blocks[0].kind == .taskList(isChecked: true, indent: 0))
        #expect(doc.blocks[0].rawText == "- [x] Task Item")

        // Toggle back to uncompleted
        doc.toggleTask(blockId: firstId)
        #expect(doc.blocks[0].kind == .taskList(isChecked: false, indent: 0))
        #expect(doc.blocks[0].rawText == "- [ ] Task Item")

        // Enter continues task list
        doc.handleEnter(at: firstId)
        #expect(doc.blocks.count == 2)
        #expect(doc.blocks[1].rawText == "- [ ] ")
        #expect(doc.blocks[1].kind == .taskList(isChecked: false, indent: 0))
    }

    @Test("Enter on table appends a new blank row")
    @MainActor
    func testEnterOnTable() {
        let markdown = """
        | Header 1 | Header 2 |
        | :--- | :--- |
        | Value 1 | Value 2 |
        """
        let doc = MeridianMarkdownDocument(initialMarkdown: markdown)
        let tableId = doc.blocks[0].id

        doc.handleEnter(at: tableId)

        guard case .table(let data) = doc.blocks[0].kind else {
            Issue.record("Expected table")
            return
        }

        #expect(data.rows.count == 2)
        #expect(data.rows[1] == ["", ""])
    }

    @Test("Enter on header creates a paragraph below")
    @MainActor
    func testEnterOnHeader() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "# Main Title")
        let headerId = doc.blocks[0].id

        doc.handleEnter(at: headerId)

        #expect(doc.blocks.count == 2)
        #expect(doc.blocks[0].kind == .header(level: 1))
        #expect(doc.blocks[1].kind == .paragraph)
        #expect(doc.blocks[1].rawText == "")
        #expect(doc.activeBlockId == doc.blocks[1].id)
    }

    @Test("Backspace on empty list item or empty block merges/reverts")
    @MainActor
    func testBackspaceBehavior() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "- ")
        let firstId = doc.blocks[0].id

        doc.handleBackspace(at: firstId)
        #expect(doc.blocks[0].kind == .paragraph)
        #expect(doc.blocks[0].rawText == "")

        // If two blocks exist and second is empty, backspace removes second
        doc.handleEnter(at: doc.blocks[0].id)
        #expect(doc.blocks.count == 2)
        let secondId = doc.blocks[1].id

        doc.handleBackspace(at: secondId)
        #expect(doc.blocks.count == 1)
        #expect(doc.activeBlockId == doc.blocks[0].id)
    }

    @Test("Block text update re-tokenizes in real-time")
    @MainActor
    func testBlockTextUpdate() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "Original Text")
        let id = doc.blocks[0].id

        doc.updateBlock(id: id, newRawText: "## New Heading")
        #expect(doc.blocks[0].kind == .header(level: 2))
        #expect(doc.blocks[0].rawText == "## New Heading")
    }

    @Test("Sample table insertion and serialization")
    @MainActor
    func testSampleTableInsertion() {
        let doc = MeridianMarkdownDocument()
        doc.insertSampleTable(at: 0)

        #expect(doc.blocks.count == 2)
        guard case .table(let data) = doc.blocks[0].kind else {
            Issue.record("Expected inserted table")
            return
        }

        #expect(data.columnCount == 3)
        #expect(data.rows.count == 1)
    }

    @Test("Activation and deactivation of blocks")
    @MainActor
    func testBlockActivation() {
        let doc = MeridianMarkdownDocument(initialMarkdown: "Line 1\nLine 2")
        let id2 = doc.blocks[1].id

        doc.activateBlock(id2)
        #expect(doc.activeBlockId == id2)

        doc.deactivateActiveBlock()
        #expect(doc.activeBlockId == nil)

        // In read-only mode, activateBlock is a no-op
        doc.isReadOnly = true
        doc.activateBlock(id2)
        #expect(doc.activeBlockId == nil)
    }
}

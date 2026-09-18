//
// MeridianMarkdownCaretTests.swift
// MeridianUITests
//
// Comprehensive unit test suite for MeridianMarkdownCaretCoordinator and precision caret insertion.
//

import Testing
import SwiftUI
#if os(macOS)
import AppKit
#endif
@testable import MeridianUI
@testable import MeridianMarkdownDemo

@Suite("Meridian Markdown Caret & Precision Insertion Tests")
struct MeridianMarkdownCaretTests {

    #if os(macOS)
    @Test("AppKit Caret Coordinator: Collapses full-text selection to zero-length caret")
    @MainActor
    func testCaretCoordinatorSelectionCollapse() throws {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        textView.string = "Welcome to Meridian Markdown Live Preview"
        let totalLength = (textView.string as NSString).length

        // Simulate AppKit's default programmatic focus behavior (selectAll)
        textView.setSelectedRange(NSRange(location: 0, length: totalLength))
        #expect(textView.selectedRange().length == totalLength)

        // Create a host window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(textView)
        window.makeFirstResponder(textView)
        #expect(window.firstResponder == textView)

        // Invoke collapseSelectionToCaret with no mouse click (keyboard / fallback mode)
        MeridianMarkdownCaretCoordinator.collapseSelectionToCaret(in: window)

        // Must collapse to length 0 (caret at end of string), never full highlight
        let collapsedRange = textView.selectedRange()
        #expect(collapsedRange.length == 0)
        #expect(collapsedRange.location == totalLength)
    }

    @Test("AppKit Caret Coordinator: Maps click coordinates inside NSTextView bounds")
    @MainActor
    func testCaretCoordinatorClickMapping() throws {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        textView.string = "First line of text\nSecond line of text"
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(textView)
        window.makeFirstResponder(textView)

        // Simulate click at top-left
        let clickPoint = NSPoint(x: 15, y: 8)
        let index = MeridianMarkdownCaretCoordinator.characterIndex(for: clickPoint, in: textView)
        #expect(index >= 0)
        #expect(index <= textView.string.count)

        // Invoke collapse with preferredLocation
        MeridianMarkdownCaretCoordinator.collapseSelectionToCaret(
            in: window,
            preferredLocation: CGPoint(x: 15, y: 8)
        )
        let range = textView.selectedRange()
        #expect(range.length == 0)
    }

    @Test("AppKit Caret Coordinator: Edge cases handle empty string, nil window, and non-NSTextView")
    @MainActor
    func testCaretCoordinatorEdgeCases() throws {
        // 1. Empty string text view
        let emptyTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        emptyTextView.string = ""
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(emptyTextView)
        window.makeFirstResponder(emptyTextView)
        MeridianMarkdownCaretCoordinator.collapseSelectionToCaret(in: window)
        #expect(emptyTextView.selectedRange().length == 0)
        #expect(emptyTextView.selectedRange().location == 0)

        // 2. Non-NSTextView first responder
        let plainView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        window.contentView?.addSubview(plainView)
        window.makeFirstResponder(plainView)
        MeridianMarkdownCaretCoordinator.collapseSelectionToCaret(in: window)

        // 3. Nil window safe execution
        MeridianMarkdownCaretCoordinator.collapseSelectionToCaret(in: nil)
    }
    #endif

    @Test("Caret Estimator: Accurately estimates character offsets across multiple lines")
    func testCharacterIndexEstimator() throws {
        let text = "Line one\nLine two is longer\nLine three"
        // (0, 0) should be index 0
        let atOrigin = MeridianMarkdownCaretCoordinator.estimateCharacterIndex(for: .zero, in: text)
        #expect(atOrigin == 0)

        // Second line (~25pt down)
        let lineTwo = MeridianMarkdownCaretCoordinator.estimateCharacterIndex(
            for: CGPoint(x: 16, y: 25),
            in: text,
            averageCharWidth: 8.0,
            lineHeight: 20.0
        )
        // Line 1 is 8 chars + 1 newline = 9. 16/8 = 2 chars into line 2 => 11
        #expect(lineTwo == 11)

        // Empty text
        #expect(MeridianMarkdownCaretCoordinator.estimateCharacterIndex(for: CGPoint(x: 10, y: 10), in: "") == 0)
    }

    @Test("Document Block Activation: Preserves and clears pending caret location")
    @MainActor
    func testDocumentPendingCaretLocationLifecycle() throws {
        let document = MeridianMarkdownDocument(initialMarkdown: "# Heading\nParagraph")
        let firstBlockID = document.blocks[0].id
        #expect(document.pendingCaretLocation == nil)

        // Activate with click location
        let clickPoint = CGPoint(x: 55, y: 12)
        document.activateBlock(firstBlockID, at: clickPoint)
        #expect(document.activeBlockId == firstBlockID)
        #expect(document.pendingCaretLocation == clickPoint)

        // Deactivate clears pending location
        document.deactivateActiveBlock()
        #expect(document.activeBlockId == nil)
        #expect(document.pendingCaretLocation == nil)
    }

    @Test("Demo App Showcase: Sample markdown exercises all GFM supported features")
    @MainActor
    func testDemoSampleMarkdownCoverage() throws {
        let sample = MeridianMarkdownDemoContentView.sampleMarkdown

        // 1. GitHub Alert Callouts
        #expect(sample.contains("> [!NOTE]"))
        #expect(sample.contains("> [!TIP]"))
        #expect(sample.contains("> [!IMPORTANT]"))
        #expect(sample.contains("> [!WARNING]"))
        #expect(sample.contains("> [!CAUTION]"))

        // 2. Table with escaped pipes
        #expect(sample.contains("\\|"))
        #expect(sample.contains("| :--- |"))

        // 3. Task checklists and nested tasks
        #expect(sample.contains("- [x]"))
        #expect(sample.contains("- [ ]"))
        #expect(sample.contains("  - [x]"))

        // 4. Inline styles & autolinks
        #expect(sample.contains("~~strikethrough~~"))
        #expect(sample.contains("<https://github.com>"))
        #expect(sample.contains("meridian_core_storage_v2"))

        // 5. Images and code block
        #expect(sample.contains("```swift"))
        #expect(sample.contains("![Meridian Architecture Engine]"))

        // 6. Verify parsing into blocks
        let blocks = MeridianMarkdownParser.parseDocument(rawText: sample)
        #expect(blocks.count > 10)
        #expect(blocks.contains(where: { if case .alert = $0.kind { return true }; return false }))
        #expect(blocks.contains(where: { if case .table = $0.kind { return true }; return false }))
        #expect(blocks.contains(where: { if case .taskList = $0.kind { return true }; return false }))
        #expect(blocks.contains(where: { if case .codeBlock = $0.kind { return true }; return false }))
        #expect(blocks.contains(where: { if case .image = $0.kind { return true }; return false }))
    }
}

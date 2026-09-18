//
// MeridianMarkdownEditorViewTests.swift
// MeridianUITests
//
// High-coverage unit tests for SwiftUI components, theme tokens, and view body evaluation
// in the MeridianMarkdownEditor suite.
//

import Testing
import Foundation
import SwiftUI
@testable import MeridianUI

@Suite("MeridianMarkdownEditor View & Theme Tests")
struct MeridianMarkdownEditorViewTests {

    @Test("Theme presets configure expected font designs and colors")
    @MainActor
    func testThemePresets() {
        let sepia = MeridianMarkdownTheme.sepia
        #expect(sepia.isSerif == true)

        let light = MeridianMarkdownTheme.light
        #expect(light.isSerif == false)

        let dark = MeridianMarkdownTheme.dark
        #expect(dark.isSerif == false)

        _ = sepia.h1Font
        _ = sepia.h2Font
        _ = sepia.h3Font
        _ = sepia.bodyFont
        _ = sepia.codeFont

        _ = light.h1Font
        _ = light.bodyFont
        _ = light.codeFont
    }

    @Test("MeridianTableAlignment text and frame alignment mapping")
    func testTableAlignmentMappings() {
        for align in MeridianTableAlignment.allCases {
            _ = align.textAlignment
            _ = align.frameAlignment
        }
        #expect(MeridianTableAlignment.leading.textAlignment == .leading)
        #expect(MeridianTableAlignment.center.textAlignment == .center)
        #expect(MeridianTableAlignment.trailing.textAlignment == .trailing)
    }

    @Test("MeridianInlineSpan rawText accessors")
    func testInlineSpanRawText() {
        #expect(MeridianInlineSpan.plain("text").rawText == "text")
        #expect(MeridianInlineSpan.bold("bold").rawText == "bold")
        #expect(MeridianInlineSpan.italic("italic").rawText == "italic")
        #expect(MeridianInlineSpan.boldItalic("both").rawText == "both")
        #expect(MeridianInlineSpan.strikethrough("strike").rawText == "strike")
        #expect(MeridianInlineSpan.inlineCode("code").rawText == "code")
        #expect(MeridianInlineSpan.link(text: "apple", url: "https://apple.com").rawText == "apple")
    }

    @Test("MeridianMarkdownTableView view body evaluation")
    @MainActor
    func testTableViewInstantiation() {
        let data = MeridianTableData(
            headers: ["Col 1", "Col 2"],
            alignments: [.leading, .trailing],
            rows: [["Val A", "Val B"], ["Val C", "Val D"]]
        )

        var selected = false
        let view = MeridianMarkdownTableView(data: data, theme: .sepia) {
            selected = true
        }

        #expect(view.data.columnCount == 2)
        #expect(view.theme == .sepia)
        #expect(selected == false)

        // Evaluate view body and force full rendering traversal
        _ = view.body
        #if canImport(AppKit)
        let renderer = ImageRenderer(content: view)
        _ = renderer.nsImage
        #endif
    }

    @Test("MeridianMarkdownInlineView view body evaluation with mixed spans")
    @MainActor
    func testInlineViewInstantiation() {
        let spans: [MeridianInlineSpan] = [
            .plain("Normal "),
            .bold("Bold"),
            .italic("Italic"),
            .boldItalic("Both"),
            .strikethrough("Strikethrough"),
            .inlineCode("Code"),
            .link(text: "Link", url: "https://apple.com")
        ]

        let view = MeridianMarkdownInlineView(spans: spans, theme: .sepia)
        #expect(view.spans.count == 7)

        // Evaluate view body
        _ = view.body
        #if canImport(AppKit)
        _ = ImageRenderer(content: view).nsImage
        #endif

        // Empty spans fallback
        let emptyView = MeridianMarkdownInlineView(spans: [], theme: .sepia)
        _ = emptyView.body
    }

    @Test("MeridianMarkdownBlockView view body evaluation across all block kinds")
    @MainActor
    func testBlockViewInstantiation() {
        let markdown = """
        # H1 Title
        ## H2 Title
        ### H3 Title
        - Bullet Item
        1. Numbered Item
        - [ ] Unchecked Task
        - [x] Checked Task
        > Blockquote message
        ---
        ```swift
        let x = 10
        ```
        | A | B |
        | --- | --- |
        | 1 | 2 |
        Standard paragraph text.
        """

        let doc = MeridianMarkdownDocument(initialMarkdown: markdown)

        for block in doc.blocks {
            // Folded inactive evaluation
            let inactiveView = MeridianMarkdownBlockView(document: doc, block: block)
            _ = inactiveView.body
            #if canImport(AppKit)
            _ = ImageRenderer(content: inactiveView).nsImage
            #endif

            // Active editing evaluation
            doc.activateBlock(block.id)
            let activeView = MeridianMarkdownBlockView(document: doc, block: block)
            _ = activeView.body
            #if canImport(AppKit)
            _ = ImageRenderer(content: activeView).nsImage
            #endif
        }
    }

    @Test("MeridianMarkdownEditor container view body evaluation")
    @MainActor
    func testEditorInstantiation() {
        let doc = MeridianMarkdownDocument(title: "Test Note", initialMarkdown: "# Header\nParagraph text.")
        let editor = MeridianMarkdownEditor(document: doc)

        #expect(editor.document.title == "Test Note")
        #expect(editor.document.blocks.count == 2)

        // Evaluate editor body
        _ = editor.body
        #if canImport(AppKit)
        _ = ImageRenderer(content: editor).nsImage
        #endif

        // Setter on markdownText
        doc.markdownText = "# Updated Header\nNew paragraph."
        #expect(doc.blocks.count == 2)
        #expect(doc.markdownText.contains("Updated Header"))
    }
}

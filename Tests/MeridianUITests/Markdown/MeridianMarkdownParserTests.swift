//
// MeridianMarkdownParserTests.swift
// MeridianUITests
//
// High-coverage unit test suite for MeridianMarkdownParser verifying block classification,
// GFM pipe tables, inline spans, and round-trip serialization.
//

import Testing
import Foundation
@testable import MeridianUI

@Suite("MeridianMarkdownParser Tests")
struct MeridianMarkdownParserTests {

    @Test("Parse headings from level 1 through 6")
    func testHeaderParsing() {
        let h1 = MeridianMarkdownParser.parseLineKind(line: "# Title 1")
        #expect(h1.kind == .header(level: 1))
        #expect(h1.content == "Title 1")

        let h2 = MeridianMarkdownParser.parseLineKind(line: "## Title 2")
        #expect(h2.kind == .header(level: 2))
        #expect(h2.content == "Title 2")

        let h3 = MeridianMarkdownParser.parseLineKind(line: "### Title 3")
        #expect(h3.kind == .header(level: 3))
        #expect(h3.content == "Title 3")

        let h6 = MeridianMarkdownParser.parseLineKind(line: "###### Title 6")
        #expect(h6.kind == .header(level: 6))
        #expect(h6.content == "Title 6")

        // Invalid heading (7 hashes) falls back to paragraph
        let h7 = MeridianMarkdownParser.parseLineKind(line: "####### Title 7")
        #expect(h7.kind == .paragraph)
    }

    @Test("Parse bullet list items with various markers")
    func testBulletListParsing() {
        let dash = MeridianMarkdownParser.parseLineKind(line: "- Item One")
        #expect(dash.kind == .bulletList(indent: 0))
        #expect(dash.content == "Item One")

        let asterisk = MeridianMarkdownParser.parseLineKind(line: "* Item Two")
        #expect(asterisk.kind == .bulletList(indent: 0))
        #expect(asterisk.content == "Item Two")

        let plus = MeridianMarkdownParser.parseLineKind(line: "+ Item Three")
        #expect(plus.kind == .bulletList(indent: 0))
        #expect(plus.content == "Item Three")
    }

    @Test("Parse numbered lists and auto-numbering prefixes")
    func testNumberedListParsing() {
        let num1 = MeridianMarkdownParser.parseLineKind(line: "1. First Item")
        #expect(num1.kind == .numberedList(index: 1, indent: 0))
        #expect(num1.content == "First Item")

        let num42 = MeridianMarkdownParser.parseLineKind(line: "42. The Answer")
        #expect(num42.kind == .numberedList(index: 42, indent: 0))
        #expect(num42.content == "The Answer")
    }

    @Test("Parse interactive task checkboxes")
    func testTaskListParsing() {
        let uncompleted = MeridianMarkdownParser.parseLineKind(line: "- [ ] Buy Groceries")
        #expect(uncompleted.kind == .taskList(isChecked: false, indent: 0))
        #expect(uncompleted.content == "Buy Groceries")

        let completed = MeridianMarkdownParser.parseLineKind(line: "- [x] Call Electrician")
        #expect(completed.kind == .taskList(isChecked: true, indent: 0))
        #expect(completed.content == "Call Electrician")

        let completedUpper = MeridianMarkdownParser.parseLineKind(line: "* [X] Submit Taxes")
        #expect(completedUpper.kind == .taskList(isChecked: true, indent: 0))
        #expect(completedUpper.content == "Submit Taxes")
    }

    @Test("Parse blockquotes and horizontal dividers")
    func testQuotesAndDividers() {
        let quote = MeridianMarkdownParser.parseLineKind(line: "> Wisdom begins with wonder.")
        #expect(quote.kind == .blockquote(indent: 0))
        #expect(quote.content == "Wisdom begins with wonder.")

        let dashRule = MeridianMarkdownParser.parseLineKind(line: "---")
        #expect(dashRule.kind == .horizontalRule)

        let starRule = MeridianMarkdownParser.parseLineKind(line: "***")
        #expect(starRule.kind == .horizontalRule)

        let underRule = MeridianMarkdownParser.parseLineKind(line: "___")
        #expect(underRule.kind == .horizontalRule)
    }

    @Test("Parse GFM pipe tables with column alignment")
    func testTableParsing() {
        let markdown = """
        | Product | Status | Price |
        | :--- | :---: | ---: |
        | Obsidian | Active | Free |
        | Meridian | Beta | $0 |
        """

        let blocks = MeridianMarkdownParser.parseDocument(rawText: markdown)
        #expect(blocks.count == 1)

        guard case .table(let tableData) = blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }

        #expect(tableData.headers == ["Product", "Status", "Price"])
        #expect(tableData.alignments == [.leading, .center, .trailing])
        #expect(tableData.rows.count == 2)
        #expect(tableData.rows[0] == ["Obsidian", "Active", "Free"])
        #expect(tableData.rows[1] == ["Meridian", "Beta", "$0"])
        #expect(tableData.columnCount == 3)
        #expect(tableData.alignment(for: 0) == .leading)
        #expect(tableData.alignment(for: 1) == .center)
        #expect(tableData.alignment(for: 2) == .trailing)
        #expect(tableData.alignment(for: 99) == .leading)
    }

    @Test("Parse fenced code blocks with language identifiers")
    func testFencedCodeParsing() {
        let markdown = """
        ```swift
        let x = 42
        print(x)
        ```
        """

        let blocks = MeridianMarkdownParser.parseDocument(rawText: markdown)
        #expect(blocks.count == 1)

        guard case .codeBlock(let lang, let code) = blocks[0].kind else {
            Issue.record("Expected code block")
            return
        }

        #expect(lang == "swift")
        #expect(code == "let x = 42\nprint(x)")
    }

    @Test("Parse rich inline formatting spans")
    func testInlineSpanParsing() {
        let text = "Hello **world** and *italics* and `code` with ~~strike~~ and [Apple](https://apple.com)!"
        let spans = MeridianMarkdownParser.parseInlineSpans(text: text)

        #expect(spans.count == 11)
        #expect(spans[0] == .plain("Hello "))
        #expect(spans[1] == .bold("world"))
        #expect(spans[2] == .plain(" and "))
        #expect(spans[3] == .italic("italics"))
        #expect(spans[4] == .plain(" and "))
        #expect(spans[5] == .inlineCode("code"))
        #expect(spans[6] == .plain(" with "))
        #expect(spans[7] == .strikethrough("strike"))
        #expect(spans[8] == .plain(" and "))
        #expect(spans[9] == .link(text: "Apple", url: "https://apple.com"))
        #expect(spans[10] == .plain("!"))
    }

    @Test("Parse bold italic combined inline spans")
    func testBoldItalicInlineSpans() {
        let text = "This is ***super bold italic*** text."
        let spans = MeridianMarkdownParser.parseInlineSpans(text: text)

        #expect(spans.count == 3)
        #expect(spans[0] == .plain("This is "))
        #expect(spans[1] == .boldItalic("super bold italic"))
        #expect(spans[2] == .plain(" text."))
        #expect(spans[1].rawText == "super bold italic")
    }

    @Test("Document serialization round-trip preservation")
    func testDocumentSerialization() {
        let raw = """
        # Testing
        A paragraph with **bold** text.
        - Bullet A
        - Bullet B
        1. Number 1
        2. Number 2
        """

        let blocks = MeridianMarkdownParser.parseDocument(rawText: raw)
        let serialized = MeridianMarkdownParser.serialize(blocks: blocks)

        #expect(serialized == raw)
    }

    @Test("Empty document produces at least one default block")
    func testEmptyDocument() {
        let blocks = MeridianMarkdownParser.parseDocument(rawText: "")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .paragraph)
    }
}

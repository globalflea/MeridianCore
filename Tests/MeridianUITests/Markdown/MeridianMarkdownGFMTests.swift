//
// MeridianMarkdownGFMTests.swift
// MeridianUITests
//
// Comprehensive unit test suite validating GitHub Flavored Markdown (GFM v0.29-gfm)
// specification compliance, table pipe escaping, autolinks, underscore intra-word rules,
// flexible thematic breaks, nested lists, and GitHub alert callout cards.
//

import Testing
import SwiftUI
@testable import MeridianUI

@Suite("GitHub Flavored Markdown (GFM) Compliance Tests")
struct MeridianMarkdownGFMTests {

    // MARK: - GFM §4.10: Tables, Escaped Pipes & Cell Inline Formatting

    @Test("GFM §4.10: Table splitTableRow respects escaped pipes and code spans")
    func testTableEscapedPipesAndCodeSpans() throws {
        let rowWithEscapedPipe = "| Operator | \\| (Bitwise OR) | Standard pipe |"
        let cells = MeridianMarkdownParser.splitTableRow(rowWithEscapedPipe)
        #expect(cells.count == 3)
        #expect(cells[0] == "Operator")
        #expect(cells[1] == "| (Bitwise OR)")
        #expect(cells[2] == "Standard pipe")

        let rowWithCodeSpanPipe = "| Command | `ls | grep foo` | Piping output |"
        let codeCells = MeridianMarkdownParser.splitTableRow(rowWithCodeSpanPipe)
        #expect(codeCells.count == 3)
        #expect(codeCells[0] == "Command")
        #expect(codeCells[1] == "`ls | grep foo`")
        #expect(codeCells[2] == "Piping output")
    }

    @Test("GFM §4.10: Formatted markdown spans within table headers and cells")
    func testFormattedMarkdownInTableCells() throws {
        let rawTable = """
        | **Function** | `Signature` | Description |
        | :--- | :---: | ---: |
        | **parse** | `(String) -> Block` | Parses *raw* markdown |
        """
        let blocks = MeridianMarkdownParser.parseDocument(rawText: rawTable)
        #expect(blocks.count == 1)
        guard case .table(let data) = blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(data.headers.count == 3)
        #expect(data.rows.count == 1)

        // Verify inline spans parsed inside header
        let headerSpans = MeridianMarkdownParser.parseInlineSpans(text: data.headers[0])
        #expect(headerSpans == [.bold("Function")])

        // Verify inline spans parsed inside cells
        let codeSpans = MeridianMarkdownParser.parseInlineSpans(text: data.rows[0][1])
        #expect(codeSpans == [.inlineCode("(String) -> Block")])

        let descSpans = MeridianMarkdownParser.parseInlineSpans(text: data.rows[0][2])
        #expect(descSpans.count == 3)
        #expect(descSpans[0] == .plain("Parses "))
        #expect(descSpans[1] == .italic("raw"))
        #expect(descSpans[2] == .plain(" markdown"))
    }

    // MARK: - GFM §4.1: Thematic Breaks

    @Test("GFM §4.1: Thematic breaks accept 3+ matching characters with optional spaces")
    func testThematicBreakVariations() throws {
        let variations = [
            "---",
            "----",
            "-----------------",
            "***",
            "* * *",
            "*  *  *",
            "___",
            "_ _ _ _"
        ]

        for variant in variations {
            let (kind, _) = MeridianMarkdownParser.parseLineKind(line: variant)
            #expect(kind == .horizontalRule, "Failed for variant: \(variant)")
        }

        // Rejections: mixed markers or fewer than 3
        let invalid = ["--", "* *", "-*-", "===", "abc"]
        for inv in invalid {
            let (kind, _) = MeridianMarkdownParser.parseLineKind(line: inv)
            #expect(kind != .horizontalRule, "Should not be horizontal rule: \(inv)")
        }
    }

    // MARK: - GFM §4.2: ATX Headings Trailing Fences

    @Test("GFM §4.2: ATX headings strip optional trailing closing hashes")
    func testATXHeadingClosingFence() throws {
        let (k1, c1) = MeridianMarkdownParser.parseLineKind(line: "# Title #")
        #expect(k1 == .header(level: 1))
        #expect(c1 == "Title")

        let (k2, c2) = MeridianMarkdownParser.parseLineKind(line: "## Subtitle ####")
        #expect(k2 == .header(level: 2))
        #expect(c2 == "Subtitle")

        let (k3, c3) = MeridianMarkdownParser.parseLineKind(line: "### Heading with # in middle ###")
        #expect(k3 == .header(level: 3))
        #expect(c3 == "Heading with # in middle")
    }

    // MARK: - GFM §6.4: Underscores & Intra-Word Delimiter Protection

    @Test("GFM §6.4: Underscore emphasis with intra-word safety for code identifiers")
    func testUnderscoreEmphasisAndIntraWordSafety() throws {
        // Safe underscore emphasis
        let italicSpans = MeridianMarkdownParser.parseInlineSpans(text: "_italic text_")
        #expect(italicSpans == [.italic("italic text")])

        let boldSpans = MeridianMarkdownParser.parseInlineSpans(text: "__bold text__")
        #expect(boldSpans == [.bold("bold text")])

        let boldItalicSpans = MeridianMarkdownParser.parseInlineSpans(text: "___bold italic___")
        #expect(boldItalicSpans == [.boldItalic("bold italic")])

        // Intra-word protection: variable names with underscores must NOT be italicized
        let codeIdentifier = "let user_account_id = 42"
        let idSpans = MeridianMarkdownParser.parseInlineSpans(text: codeIdentifier)
        #expect(idSpans == [.plain("let user_account_id = 42")])

        let mixed = "Check `code` and _italic_ and snake_case_identifier"
        let mixedSpans = MeridianMarkdownParser.parseInlineSpans(text: mixed)
        #expect(mixedSpans.count == 5)
        #expect(mixedSpans[0] == .plain("Check "))
        #expect(mixedSpans[1] == .inlineCode("code"))
        #expect(mixedSpans[2] == .plain(" and "))
        #expect(mixedSpans[3] == .italic("italic"))
        #expect(mixedSpans[4] == .plain(" and snake_case_identifier"))
    }

    // MARK: - GFM §6.8 & §6.9: Autolinks

    @Test("GFM §6.8 & §6.9: CommonMark and GFM extended autolinks")
    func testAutolinks() throws {
        // Angle-bracket autolinks (CommonMark §6.8)
        let angleUrl = "Visit <https://apple.com> for info"
        let s1 = MeridianMarkdownParser.parseInlineSpans(text: angleUrl)
        #expect(s1.count == 3)
        #expect(s1[1] == .link(text: "https://apple.com", url: "https://apple.com"))

        let angleMail = "Contact <developer@apple.com> today"
        let s2 = MeridianMarkdownParser.parseInlineSpans(text: angleMail)
        #expect(s2.count == 3)
        #expect(s2[1] == .link(text: "developer@apple.com", url: "mailto:developer@apple.com"))

        // Bare URLs (GFM §6.9)
        let bareHttps = "Docs at https://swift.org/documentation/ now."
        let s3 = MeridianMarkdownParser.parseInlineSpans(text: bareHttps)
        #expect(s3.count == 3)
        #expect(s3[1] == .link(text: "https://swift.org/documentation/", url: "https://swift.org/documentation/"))

        // www autolink (GFM §6.9)
        let wwwLink = "Go to www.google.com for search"
        let s4 = MeridianMarkdownParser.parseInlineSpans(text: wwwLink)
        #expect(s4.count == 3)
        #expect(s4[1] == .link(text: "www.google.com", url: "http://www.google.com"))
    }

    // MARK: - GFM §5.2 & §5.3: Lists & Indentation

    @Test("GFM §5.2 & §5.3: Indented sub-lists and task list markers")
    func testNestedListIndentationAndTasks() throws {
        let (k1, _) = MeridianMarkdownParser.parseLineKind(line: "  - indented bullet")
        #expect(k1 == .bulletList(indent: 1))

        let (k2, _) = MeridianMarkdownParser.parseLineKind(line: "    - deep bullet")
        #expect(k2 == .bulletList(indent: 2))

        let (k3, c3) = MeridianMarkdownParser.parseLineKind(line: "+ plus bullet")
        #expect(k3 == .bulletList(indent: 0))
        #expect(c3 == "plus bullet")

        let (k4, _) = MeridianMarkdownParser.parseLineKind(line: "+ [ ] plus task unchecked")
        #expect(k4 == .taskList(isChecked: false, indent: 0))

        let (k5, _) = MeridianMarkdownParser.parseLineKind(line: "  + [x] plus task checked")
        #expect(k5 == .taskList(isChecked: true, indent: 1))

        let (k6, c6) = MeridianMarkdownParser.parseLineKind(line: "1. [ ] ordered task item")
        #expect(k6 == .taskList(isChecked: false, indent: 0))
        #expect(c6 == "1. ordered task item")
    }

    // MARK: - Modern GitHub Alert Callouts

    @Test("Modern GitHub Alerts: [!NOTE], [!TIP], [!IMPORTANT], [!WARNING], [!CAUTION]")
    func testGitHubAlertCallouts() throws {
        let alertLines = [
            ("> [!NOTE] This is a note", MeridianAlertKind.note, "This is a note"),
            ("> [!TIP] Useful tip here", MeridianAlertKind.tip, "Useful tip here"),
            ("> [!IMPORTANT] Critical requirement", MeridianAlertKind.important, "Critical requirement"),
            ("> [!WARNING] Breaking change ahead", MeridianAlertKind.warning, "Breaking change ahead"),
            ("> [!CAUTION] Irreversible action", MeridianAlertKind.caution, "Irreversible action")
        ]

        for (line, expectedKind, expectedContent) in alertLines {
            let (kind, content) = MeridianMarkdownParser.parseLineKind(line: line)
            #expect(kind == .alert(kind: expectedKind, content: expectedContent))
            #expect(content == expectedContent)
        }
    }

    // MARK: - GFM §6.7: Images

    @Test("GFM §6.7: Standalone image blocks and inline images")
    func testImages() throws {
        let imageLine = "![App Logo](https://example.com/logo.png)"
        let (kind, _) = MeridianMarkdownParser.parseLineKind(line: imageLine)
        #expect(kind == .image(alt: "App Logo", url: "https://example.com/logo.png"))

        let inlineImg = "Header with ![Icon](https://example.com/icon.png) embedded"
        let spans = MeridianMarkdownParser.parseInlineSpans(text: inlineImg)
        #expect(spans.count == 3)
        #expect(spans[1] == .image(alt: "Icon", url: "https://example.com/icon.png"))
        #expect(spans[1].rawText == "Icon")
    }

    // MARK: - View Evaluation

    @Test("MeridianMarkdownCalloutView renders body for all alert kinds")
    @MainActor
    func testCalloutViewRendering() throws {
        let theme = MeridianMarkdownTheme.sepia
        for kind in MeridianAlertKind.allCases {
            let view = MeridianMarkdownCalloutView(
                kind: kind,
                content: "Alert body for **\(kind.title)** and `code`",
                theme: theme
            )
            #expect(view.accentColor != Color.clear)
            #expect(!kind.iconSystemName.isEmpty)
            let renderer = ImageRenderer(content: view)
            _ = renderer.cgImage
        }
    }

    @Test("MeridianMarkdownBlockView evaluates alert and image blocks")
    @MainActor
    func testBlockViewAlertAndImageEvaluation() throws {
        let doc = MeridianMarkdownDocument(initialMarkdown: "> [!NOTE] Note body")
        guard let alertBlock = doc.blocks.first else { return }
        let alertView = MeridianMarkdownBlockView(document: doc, block: alertBlock)
        let r1 = ImageRenderer(content: alertView)
        _ = r1.cgImage

        let doc2 = MeridianMarkdownDocument(initialMarkdown: "![Logo](https://example.com/logo.png)")
        guard let imgBlock = doc2.blocks.first else { return }
        let imgView = MeridianMarkdownBlockView(document: doc2, block: imgBlock)
        let r2 = ImageRenderer(content: imgView)
        _ = r2.cgImage

        // Update table block in document
        let tableDoc = MeridianMarkdownDocument(initialMarkdown: "| H1 |\n| --- |\n| C1 |")
        if let tableId = tableDoc.blocks.first?.id {
            tableDoc.updateBlock(id: tableId, newRawText: "| H1 | H2 |\n| --- | --- |\n| C1 | C2 |")
            #expect(tableDoc.blocks.first?.rawText.contains("H2") == true)
        }
    }
}

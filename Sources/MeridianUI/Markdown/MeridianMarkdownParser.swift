//
// MeridianMarkdownParser.swift
// MeridianUI
//
// Pure Swift 6 zero-dependency incremental parser and tokenizer for Markdown blocks,
// GFM pipe tables, and rich inline spans.
//

import Foundation

/// Algorithmic scanner and tokenizer for CommonMark and GFM Markdown text.
public enum MeridianMarkdownParser: Sendable {

    /// Parses a complete Markdown string into structured, identifiable blocks.
    ///
    /// Handles fenced code blocks, GFM tables, headings, lists, tasks, quotes, and paragraphs.
    ///
    /// - Parameter rawText: Full raw document text.
    /// - Returns: Array of parsed `MeridianMarkdownBlock` units.
    public static func parseDocument(rawText: String) -> [MeridianMarkdownBlock] {
        let lines = rawText.components(separatedBy: "\n")
        var blocks: [MeridianMarkdownBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // 1. Check for Fenced Code Block: ```lang
            if let (codeBlock, consumed) = parseFencedCode(lines: lines, startIndex: i) {
                blocks.append(codeBlock)
                i += consumed
                continue
            }

            // 2. Check for GFM Pipe Table
            if let (tableBlock, consumed) = parseTableBlock(lines: lines, startIndex: i) {
                blocks.append(tableBlock)
                i += consumed
                continue
            }

            // 3. Single-Line Elements
            let (kind, content) = parseLineKind(line: line)
            let spans = parseInlineSpans(text: content)
            blocks.append(MeridianMarkdownBlock(kind: kind, rawText: line, inlineSpans: spans))
            i += 1
        }

        // Always ensure at least one editable block exists
        if blocks.isEmpty {
            blocks.append(MeridianMarkdownBlock(kind: .paragraph, rawText: "", inlineSpans: []))
        }

        return blocks
    }

    /// Parses a single line's block classification and its stripped inner content text.
    public static func parseLineKind(line: String) -> (kind: MeridianBlockKind, content: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Empty line
        if trimmed.isEmpty {
            return (.paragraph, "")
        }

        // Horizontal Rule: ---, ***, ___ (at least 3 characters)
        if (trimmed == "---" || trimmed == "***" || trimmed == "___") {
            return (.horizontalRule, "")
        }

        // Headings: # through ######
        if trimmed.hasPrefix("#") {
            var level = 0
            for char in trimmed {
                if char == "#" { level += 1 } else { break }
            }
            if level <= 6 && trimmed.count > level {
                let index = trimmed.index(trimmed.startIndex, offsetBy: level)
                if trimmed[index] == " " {
                    let content = String(trimmed[trimmed.index(after: index)...])
                    return (.header(level: level), content)
                }
            }
        }

        // Blockquote: > text
        if trimmed.hasPrefix(">") {
            let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            return (.blockquote(indent: 0), String(content))
        }

        // Task List: - [ ] or - [x] or * [ ] or * [x]
        if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("* [ ] ") {
            let content = String(trimmed.dropFirst(6))
            return (.taskList(isChecked: false, indent: 0), content)
        }
        if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") ||
           trimmed.hasPrefix("* [x] ") || trimmed.hasPrefix("* [X] ") {
            let content = String(trimmed.dropFirst(6))
            return (.taskList(isChecked: true, indent: 0), content)
        }

        // Bullet List: - item, * item, + item, or empty bullet prefix
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") || trimmed == "-" || trimmed == "*" || trimmed == "+" {
            let content = line.count >= 2 ? String(line.dropFirst(2)) : ""
            return (.bulletList(indent: 0), content)
        }

        // Numbered List: 1. item or empty 1. prefix
        if let (number, content) = parseNumberedListPrefix(line) {
            return (.numberedList(index: number, indent: 0), content)
        }

        // Default: Paragraph
        return (.paragraph, trimmed)
    }

    /// Detects and parses a GFM Table starting at `startIndex`.
    private static func parseTableBlock(lines: [String], startIndex: Int) -> (MeridianMarkdownBlock, consumed: Int)? {
        guard startIndex + 1 < lines.count else { return nil }
        let headerLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let delimiterLine = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)

        guard headerLine.contains("|") && delimiterLine.contains("|") else { return nil }

        // Validate delimiter row (contains only |, -, :, space)
        let delimiterCells = splitTableRow(delimiterLine)
        guard !delimiterCells.isEmpty else { return nil }
        var alignments: [MeridianTableAlignment] = []

        for cell in delimiterCells {
            let c = cell.trimmingCharacters(in: .whitespaces)
            guard c.contains("-") && c.allSatisfy({ $0 == "-" || $0 == ":" }) else {
                return nil
            }
            let leadingColon = c.hasPrefix(":")
            let trailingColon = c.hasSuffix(":")
            if leadingColon && trailingColon {
                alignments.append(.center)
            } else if trailingColon {
                alignments.append(.trailing)
            } else {
                alignments.append(.leading)
            }
        }

        let headers = splitTableRow(headerLine)
        guard headers.count == alignments.count else { return nil }

        var rows: [[String]] = []
        var consumed = 2
        var rawLines = [lines[startIndex], lines[startIndex + 1]]

        while startIndex + consumed < lines.count {
            let rowLine = lines[startIndex + consumed]
            let trimmedRow = rowLine.trimmingCharacters(in: .whitespaces)
            if trimmedRow.isEmpty || !trimmedRow.contains("|") {
                break
            }
            let cells = splitTableRow(trimmedRow)
            rows.append(cells)
            rawLines.append(rowLine)
            consumed += 1
        }

        let tableData = MeridianTableData(headers: headers, alignments: alignments, rows: rows)
        let block = MeridianMarkdownBlock(
            kind: .table(data: tableData),
            rawText: rawLines.joined(separator: "\n"),
            inlineSpans: []
        )
        return (block, consumed)
    }

    /// Splits a table row string into trimmed cells, ignoring leading and trailing pipes.
    public static func splitTableRow(_ row: String) -> [String] {
        var s = row.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Parses fenced code block ```lang ... ```
    private static func parseFencedCode(lines: [String], startIndex: Int) -> (MeridianMarkdownBlock, consumed: Int)? {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard firstLine.hasPrefix("```") else { return nil }
        let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)

        var codeLines: [String] = []
        var consumed = 1

        while startIndex + consumed < lines.count {
            let line = lines[startIndex + consumed]
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                consumed += 1
                break
            }
            codeLines.append(line)
            consumed += 1
        }

        let code = codeLines.joined(separator: "\n")
        let fullRaw = lines[startIndex..<(startIndex + consumed)].joined(separator: "\n")
        let block = MeridianMarkdownBlock(kind: .codeBlock(language: language, code: code), rawText: fullRaw)
        return (block, consumed)
    }

    private static func parseNumberedListPrefix(_ line: String) -> (Int, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var digits = ""
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex && trimmed[idx].isNumber {
            digits.append(trimmed[idx])
            idx = trimmed.index(after: idx)
        }
        guard !digits.isEmpty, let number = Int(digits), idx < trimmed.endIndex else { return nil }
        guard trimmed[idx] == "." else { return nil }
        idx = trimmed.index(after: idx)
        if idx == trimmed.endIndex {
            return (number, "")
        }
        guard trimmed[idx] == " " else { return nil }
        let content = String(trimmed[trimmed.index(after: idx)...])
        return (number, content)
    }

    /// Serializes an array of blocks back into pure Markdown string losslessly.
    public static func serialize(blocks: [MeridianMarkdownBlock]) -> String {
        blocks.map(\.rawText).joined(separator: "\n")
    }
}

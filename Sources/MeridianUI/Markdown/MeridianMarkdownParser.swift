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

        // Calculate leading space indentation level (GFM §5.2)
        var leadingSpaces = 0
        for ch in line {
            if ch == " " { leadingSpaces += 1 }
            else if ch == "\t" { leadingSpaces += 4 }
            else { break }
        }
        let indent = leadingSpaces / 2

        // Thematic Break: 3+ matching -, *, or _ with optional spaces (GFM §4.1)
        if isThematicBreak(trimmed) {
            return (.horizontalRule, "")
        }

        // Standalone Image: ![alt](url) (GFM §6.7)
        if let image = parseImageBlock(trimmed) {
            return (.image(alt: image.alt, url: image.url), image.alt)
        }

        // Headings: # through ###### (GFM §4.2)
        if trimmed.hasPrefix("#") {
            var level = 0
            for char in trimmed {
                if char == "#" { level += 1 } else { break }
            }
            if level <= 6 {
                let afterHash = trimmed.dropFirst(level)
                if afterHash.isEmpty {
                    return (.header(level: level), "")
                }
                if afterHash.first == " " {
                    var content = String(afterHash.dropFirst())
                    // Strip optional trailing # closing sequence preceded by space
                    let trimmedContent = content.trimmingCharacters(in: .whitespaces)
                    if trimmedContent.hasSuffix("#") {
                        var end = trimmedContent.endIndex
                        while end > trimmedContent.startIndex && trimmedContent[trimmedContent.index(before: end)] == "#" {
                            end = trimmedContent.index(before: end)
                        }
                        let beforeHash = trimmedContent[..<end]
                        if beforeHash.hasSuffix(" ") || beforeHash.isEmpty {
                            content = String(beforeHash).trimmingCharacters(in: .whitespaces)
                        }
                    }
                    return (.header(level: level), content)
                }
            }
        }

        // Blockquote / GitHub Alert: > text (GFM §5.1)
        if trimmed.hasPrefix(">") {
            let inner = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            if let alert = parseAlertCallout(inner) {
                return (.alert(kind: alert.kind, content: alert.content), alert.content)
            }
            return (.blockquote(indent: indent), String(inner))
        }

        // Task List: - [ ], + [ ], * [ ], 1. [ ] (GFM §5.3)
        if let task = parseTaskPrefix(trimmed) {
            return (.taskList(isChecked: task.isChecked, indent: indent), task.content)
        }

        // Bullet List: - item, * item, + item, or empty bullet marker (GFM §5.2)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") ||
           trimmed == "-" || trimmed == "*" || trimmed == "+" {
            let content = trimmed.count >= 2 ? String(trimmed.dropFirst(2)) : ""
            return (.bulletList(indent: indent), content)
        }

        // Numbered List: 1. item or empty 1. prefix (GFM §5.2)
        if let (number, content) = parseNumberedListPrefix(trimmed) {
            return (.numberedList(index: number, indent: indent), content)
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

    /// Splits a table row into trimmed cells, respecting escaped pipes (`\|`) and code spans.
    public static func splitTableRow(_ row: String) -> [String] {
        var text = row.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") && !text.hasSuffix("\\|") { text.removeLast() }

        var cells: [String] = []
        var currentCell = ""
        var inCode = false
        var isEscaped = false

        for char in text {
            if isEscaped {
                if char == "|" {
                    currentCell.append("|") // Unescape escaped pipe
                } else {
                    currentCell.append("\\")
                    currentCell.append(char)
                }
                isEscaped = false
            } else if char == "\\" {
                isEscaped = true
            } else if char == "`" {
                inCode.toggle()
                currentCell.append("`")
            } else if char == "|" && !inCode {
                cells.append(currentCell.trimmingCharacters(in: .whitespaces))
                currentCell = ""
            } else {
                currentCell.append(char)
            }
        }
        if isEscaped { currentCell.append("\\") }
        cells.append(currentCell.trimmingCharacters(in: .whitespaces))
        return cells
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

    /// Serializes an array of blocks back into pure Markdown string losslessly.
    public static func serialize(blocks: [MeridianMarkdownBlock]) -> String {
        blocks.map(\.rawText).joined(separator: "\n")
    }
}

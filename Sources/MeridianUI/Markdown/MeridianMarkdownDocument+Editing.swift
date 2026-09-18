//
// MeridianMarkdownDocument+Editing.swift
// MeridianUI
//
// Domain-driven editing extensions implementing smart list continuation on Enter,
// empty list termination on Backspace, task toggling, and block reordering.
//

import Foundation

public extension MeridianMarkdownDocument {

    /// Handles keyboard Enter/Return pressed on an active block.
    ///
    /// Implements smart Markdown list continuations:
    /// - Non-empty bullet list `- item` -> creates next `- ` bullet below.
    /// - Empty bullet list `- ` -> resets to standard paragraph (exits list).
    /// - Non-empty numbered list `1. item` -> creates auto-incremented `2. ` below.
    /// - Empty numbered list `1. ` -> resets to standard paragraph.
    /// - Header -> commits header and spawns a new paragraph below.
    /// - Table -> appends a new empty row to the table.
    ///
    /// - Parameter blockId: The identifier of the block where Enter was triggered.
    func handleEnter(at blockId: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        let currentBlock = blocks[index]

        switch currentBlock.kind {
        case .bulletList(let indent):
            let trimmed = currentBlock.rawText.trimmingCharacters(in: .whitespaces)
            if trimmed == "-" || trimmed == "*" || trimmed == "+" {
                // Empty bullet: Exit list and revert to empty paragraph
                blocks[index].kind = .paragraph
                blocks[index].rawText = ""
                blocks[index].inlineSpans = []
                self.activeBlockId = blocks[index].id
            } else {
                // Continue bullet list
                let prefix = String(repeating: "  ", count: indent) + "- "
                let newBlock = MeridianMarkdownBlock(
                    kind: .bulletList(indent: indent),
                    rawText: prefix,
                    inlineSpans: []
                )
                blocks.insert(newBlock, at: index + 1)
                self.activeBlockId = newBlock.id
            }

        case .numberedList(let number, let indent):
            let trimmed = currentBlock.rawText.trimmingCharacters(in: .whitespaces)
            if trimmed == "\(number)." {
                // Empty number: Exit ordered list
                blocks[index].kind = .paragraph
                blocks[index].rawText = ""
                blocks[index].inlineSpans = []
                self.activeBlockId = blocks[index].id
            } else {
                // Auto-increment numbered list
                let nextNumber = number + 1
                let prefix = String(repeating: "  ", count: indent) + "\(nextNumber). "
                let newBlock = MeridianMarkdownBlock(
                    kind: .numberedList(index: nextNumber, indent: indent),
                    rawText: prefix,
                    inlineSpans: []
                )
                blocks.insert(newBlock, at: index + 1)
                self.activeBlockId = newBlock.id
            }

        case .taskList(_, let indent):
            let trimmed = currentBlock.rawText.trimmingCharacters(in: .whitespaces)
            if trimmed == "- [ ]" || trimmed == "* [ ]" {
                // Empty task: Exit task list
                blocks[index].kind = .paragraph
                blocks[index].rawText = ""
                blocks[index].inlineSpans = []
                self.activeBlockId = blocks[index].id
            } else {
                let prefix = String(repeating: "  ", count: indent) + "- [ ] "
                let newBlock = MeridianMarkdownBlock(
                    kind: .taskList(isChecked: false, indent: indent),
                    rawText: prefix,
                    inlineSpans: []
                )
                blocks.insert(newBlock, at: index + 1)
                self.activeBlockId = newBlock.id
            }

        case .table(var tableData):
            // Append a blank row with matching column count
            let blankRow = Array(repeating: "", count: tableData.columnCount)
            tableData.rows.append(blankRow)
            let newRaw = serializeTable(tableData)
            blocks[index].kind = .table(data: tableData)
            blocks[index].rawText = newRaw

        case .header, .horizontalRule, .codeBlock, .blockquote, .paragraph:
            // Standard block continuation: spawn paragraph below
            let newBlock = MeridianMarkdownBlock(
                kind: .paragraph,
                rawText: "",
                inlineSpans: []
            )
            blocks.insert(newBlock, at: index + 1)
            self.activeBlockId = newBlock.id
        }
    }

    /// Handles Backspace pressed at the beginning of a block.
    func handleBackspace(at blockId: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        let currentBlock = blocks[index]

        // If list item or header is empty or at prefix, convert back to plain paragraph
        switch currentBlock.kind {
        case .bulletList, .numberedList, .taskList, .header, .blockquote:
            let trimmed = currentBlock.rawText.trimmingCharacters(in: .whitespaces)
            if trimmed == "-" || trimmed == "*" || trimmed.hasSuffix(".") || trimmed.hasPrefix("#") || trimmed == ">" {
                blocks[index].kind = .paragraph
                blocks[index].rawText = ""
                blocks[index].inlineSpans = []
                return
            }
        default:
            break
        }

        // If block is completely empty and there is a preceding block, delete it and focus previous
        if currentBlock.rawText.isEmpty && blocks.count > 1 {
            let previousIndex = max(0, index - 1)
            let previousId = blocks[previousIndex].id
            blocks.remove(at: index)
            self.activeBlockId = previousId
        }
    }

    /// Toggles the completion state of a task list checkbox block.
    func toggleTask(blockId: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        guard case .taskList(let isChecked, let indent) = blocks[index].kind else { return }

        let newChecked = !isChecked
        blocks[index].kind = .taskList(isChecked: newChecked, indent: indent)

        var text = blocks[index].rawText
        if newChecked {
            text = text.replacingOccurrences(of: "- [ ]", with: "- [x]")
                       .replacingOccurrences(of: "* [ ]", with: "* [x]")
        } else {
            text = text.replacingOccurrences(of: "- [x]", with: "- [ ]")
                       .replacingOccurrences(of: "- [X]", with: "- [ ]")
                       .replacingOccurrences(of: "* [x]", with: "* [ ]")
                       .replacingOccurrences(of: "* [X]", with: "* [ ]")
        }
        blocks[index].rawText = text
    }

    /// Appends a new table with sample headers and an empty row.
    func insertSampleTable(at index: Int) {
        let headers = ["Column 1", "Column 2", "Column 3"]
        let alignments: [MeridianTableAlignment] = [.leading, .center, .trailing]
        let rows = [["Data A", "Data B", "Data C"]]
        let data = MeridianTableData(headers: headers, alignments: alignments, rows: rows)
        let raw = serializeTable(data)
        let block = MeridianMarkdownBlock(kind: .table(data: data), rawText: raw)
        let insertAt = min(max(0, index), blocks.count)
        blocks.insert(block, at: insertAt)
        self.activeBlockId = block.id
    }

    /// Converts table data into clean GFM Markdown pipe format.
    private func serializeTable(_ data: MeridianTableData) -> String {
        guard !data.headers.isEmpty else { return "" }
        var lines: [String] = []

        // Header line
        let headerRow = "| " + data.headers.joined(separator: " | ") + " |"
        lines.append(headerRow)

        // Delimiter line
        let delimiterRow = "| " + data.alignments.map { alignment in
            switch alignment {
            case .leading: return ":---"
            case .center: return ":---:"
            case .trailing: return "---:"
            }
        }.joined(separator: " | ") + " |"
        lines.append(delimiterRow)

        // Rows
        for row in data.rows {
            let cells = (0..<data.columnCount).map { colIndex in
                colIndex < row.count ? row[colIndex] : ""
            }
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }

        return lines.joined(separator: "\n")
    }
}

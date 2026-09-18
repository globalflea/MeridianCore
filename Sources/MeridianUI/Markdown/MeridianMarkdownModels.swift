//
// MeridianMarkdownModels.swift
// MeridianUI
//
// Core value-type data structures, block kinds, table configurations, and inline span models
// for the MeridianMarkdownEditor system.
//

import SwiftUI

/// Text alignment specification for a table column.
public enum MeridianTableAlignment: Sendable, Hashable, CaseIterable {
    case leading
    case center
    case trailing

    /// Corresponding SwiftUI alignment.
    public var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// Corresponding SwiftUI Frame alignment.
    public var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

/// Structural representation of a GitHub Flavored Markdown (GFM) pipe table.
public struct MeridianTableData: Sendable, Hashable, Equatable {
    /// Header row labels for each column.
    public var headers: [String]

    /// Alignment rules per column.
    public var alignments: [MeridianTableAlignment]

    /// Matrix of row cell strings `[row][column]`.
    public var rows: [[String]]

    /// Creates a table data container.
    ///
    /// - Parameters:
    ///   - headers: Column titles.
    ///   - alignments: Per-column alignment directives.
    ///   - rows: 2D array of row cells.
    public init(
        headers: [String] = [],
        alignments: [MeridianTableAlignment] = [],
        rows: [[String]] = []
    ) {
        self.headers = headers
        self.alignments = alignments
        self.rows = rows
    }

    /// Number of columns defined by the headers.
    public var columnCount: Int {
        headers.count
    }

    /// Returns the alignment for a given column index, defaulting to `.leading`.
    public func alignment(for columnIndex: Int) -> MeridianTableAlignment {
        guard columnIndex < alignments.count else { return .leading }
        return alignments[columnIndex]
    }
}

/// Semantic categorization of a block-level Markdown element.
public enum MeridianBlockKind: Sendable, Hashable, Equatable {
    /// Header line with level from 1 (`#`) to 6 (`######`).
    case header(level: Int)

    /// Bullet list item with nesting indentation level.
    case bulletList(indent: Int)

    /// Ordered list item with numeric display index and indentation level.
    case numberedList(index: Int, indent: Int)

    /// Interactive task item with checkbox state and indentation level.
    case taskList(isChecked: Bool, indent: Int)

    /// Formatted GFM pipe table.
    case table(data: MeridianTableData)

    /// Blockquote container with nesting level.
    case blockquote(indent: Int)

    /// Horizontal dividing rule (`---`, `***`, `___`).
    case horizontalRule

    /// Fenced code block with optional syntax language tag.
    case codeBlock(language: String, code: String)

    /// Standard body text paragraph.
    case paragraph
}

/// Formatted inline typographical span within a block.
public enum MeridianInlineSpan: Sendable, Hashable, Equatable {
    /// Plain unadorned text.
    case plain(String)

    /// Strongly emphasized text (`**bold**` or `__bold__`).
    case bold(String)

    /// Emphasized text (`*italic*` or `_italic_`).
    case italic(String)

    /// Combined bold and italic text (`***bold-italic***`).
    case boldItalic(String)

    /// Strikethrough text (`~~strikethrough~~`).
    case strikethrough(String)

    /// Monospace code snippet (`` `code` ``).
    case inlineCode(String)

    /// Hyperlink anchor with display text and target URL.
    case link(text: String, url: String)

    /// Raw plain text extraction from the span.
    public var rawText: String {
        switch self {
        case .plain(let text),
             .bold(let text),
             .italic(let text),
             .boldItalic(let text),
             .strikethrough(let text),
             .inlineCode(let text):
            return text
        case .link(let text, _):
            return text
        }
    }
}

/// An identifiable, mutable unit of block content within a `MeridianMarkdownDocument`.
public struct MeridianMarkdownBlock: Identifiable, Sendable, Hashable, Equatable {
    /// Unique stable identifier for this block.
    public let id: UUID

    /// Semantic block kind determining rendering and behavior.
    public var kind: MeridianBlockKind

    /// Raw Markdown string representing this block in storage.
    public var rawText: String

    /// Pre-tokenized inline formatting spans.
    public var inlineSpans: [MeridianInlineSpan]

    /// Initializes a new Markdown block.
    ///
    /// - Parameters:
    ///   - id: Unique block ID (defaults to new UUID).
    ///   - kind: Block classification.
    ///   - rawText: Raw Markdown text for the block.
    ///   - inlineSpans: Parsed inline spans (defaults to empty).
    public init(
        id: UUID = UUID(),
        kind: MeridianBlockKind = .paragraph,
        rawText: String = "",
        inlineSpans: [MeridianInlineSpan] = []
    ) {
        self.id = id
        self.kind = kind
        self.rawText = rawText
        self.inlineSpans = inlineSpans
    }
}

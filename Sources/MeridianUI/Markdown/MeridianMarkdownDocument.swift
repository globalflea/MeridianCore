//
// MeridianMarkdownDocument.swift
// MeridianUI
//
// Authoritative @Observable state model managing the document blocks, live preview mode,
// active caret focus, themes, and word/character analytics.
//

import SwiftUI

/// Reactive, observable document model representing an editable Markdown document.
///
/// Adheres strictly to the single-source-of-truth principle with losslessly serializable Markdown text.
@Observable
@MainActor
public final class MeridianMarkdownDocument {

    /// The human-readable title of the document.
    public var title: String

    /// Ordered sequence of content blocks comprising the document.
    public var blocks: [MeridianMarkdownBlock]

    /// The identifier of the currently focused block (showing raw markdown syntax), or `nil`.
    public var activeBlockId: UUID?

    /// Coordinate of the click that triggered block activation, if any.
    public var pendingCaretLocation: CGPoint?

    /// Active theme governing colors and typography.
    public var theme: MeridianMarkdownTheme

    /// Whether live-preview inline folding is active (`true`) or pure raw source view (`false`).
    public var isLivePreviewEnabled: Bool

    /// Whether the document is in read-only / book presentation mode.
    public var isReadOnly: Bool

    /// Initializes a new Markdown document.
    ///
    /// - Parameters:
    ///   - title: Document title (default: "Untitled").
    ///   - initialMarkdown: Starting raw Markdown text.
    ///   - theme: Initial visual theme (default: `.sepia`).
    public init(
        title: String = "Untitled",
        initialMarkdown: String = "",
        theme: MeridianMarkdownTheme = .sepia
    ) {
        self.title = title
        self.theme = theme
        self.isLivePreviewEnabled = true
        self.isReadOnly = false
        self.blocks = MeridianMarkdownParser.parseDocument(rawText: initialMarkdown)
        self.activeBlockId = nil
    }

    /// Serializes all blocks back into a pure, standard Markdown string.
    public var markdownText: String {
        get {
            MeridianMarkdownParser.serialize(blocks: blocks)
        }
        set {
            loadMarkdown(newValue)
        }
    }

    /// Re-parses and replaces the entire document state from raw Markdown.
    public func loadMarkdown(_ rawText: String) {
        let parsed = MeridianMarkdownParser.parseDocument(rawText: rawText)
        self.blocks = parsed
        if let active = activeBlockId, !blocks.contains(where: { $0.id == active }) {
            self.activeBlockId = blocks.first?.id
        }
    }

    /// Total word count across all document blocks.
    public var wordCount: Int {
        blocks.reduce(0) { count, block in
            let words = block.rawText
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            return count + words.count
        }
    }

    /// Total character count across all document blocks.
    public var characterCount: Int {
        blocks.reduce(0) { $0 + $1.rawText.count }
    }

    /// Activates a specific block for raw character editing, optionally at a mouse click coordinate.
    public func activateBlock(_ id: UUID?, at location: CGPoint? = nil) {
        guard !isReadOnly else { return }
        self.activeBlockId = id
        self.pendingCaretLocation = location
    }

    /// Deactivates the currently active block, triggering live-preview folding.
    public func deactivateActiveBlock() {
        self.activeBlockId = nil
        self.pendingCaretLocation = nil
    }

    /// Updates the raw text of a specific block and immediately re-tokenizes its inline spans and kind.
    public func updateBlock(id: UUID, newRawText: String) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }

        // If the block is currently a table, retain table kind if it remains valid table syntax
        if case .table = blocks[index].kind {
            if let tableBlock = MeridianMarkdownParser.parseDocument(rawText: newRawText).first,
               case .table = tableBlock.kind {
                blocks[index].kind = tableBlock.kind
                blocks[index].rawText = newRawText
                blocks[index].inlineSpans = []
                return
            }
        }

        let (kind, content) = MeridianMarkdownParser.parseLineKind(line: newRawText)
        let spans = MeridianMarkdownParser.parseInlineSpans(text: content)

        blocks[index].kind = kind
        blocks[index].rawText = newRawText
        blocks[index].inlineSpans = spans
    }
}

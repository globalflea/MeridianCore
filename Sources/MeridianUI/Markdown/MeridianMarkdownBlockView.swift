//
// MeridianMarkdownBlockView.swift
// MeridianUI
//
// Block-level view dispatcher rendering either active raw Markdown editing controls
// or folded live-preview typography matching the Obsidian Sepia aesthetic.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Renders a single block in either active edit mode or folded live-preview mode.
public struct MeridianMarkdownBlockView: View {
    @Bindable public var document: MeridianMarkdownDocument
    public let block: MeridianMarkdownBlock

    @FocusState private var isFieldFocused: Bool

    /// Creates a block view.
    public init(document: MeridianMarkdownDocument, block: MeridianMarkdownBlock) {
        self.document = document
        self.block = block
    }

    private var isActive: Bool {
        document.activeBlockId == block.id && !document.isReadOnly
    }

    public var body: some View {
        Group {
            if isActive || !document.isLivePreviewEnabled {
                activeEditorView
            } else {
                inactiveFoldedView
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Active Raw Editor View

    @ViewBuilder
    private var activeEditorView: some View {
        let binding = Binding<String>(
            get: {
                document.blocks.first(where: { $0.id == block.id })?.rawText ?? block.rawText
            },
            set: { document.updateBlock(id: block.id, newRawText: $0) }
        )

        HStack(alignment: .top, spacing: 6) {
            TextField("", text: binding, axis: .vertical)
                .textFieldStyle(.plain)
                .font(themeFontForActiveKind(block.kind))
                .foregroundColor(document.theme.text)
                .focused($isFieldFocused)
                .onSubmit {
                    document.handleEnter(at: block.id)
                }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(document.theme.tableHeaderBackground.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task {
            isFieldFocused = true
            #if os(macOS)
            NSApplication.shared.activate(ignoringOtherApps: true)
            #endif
        }
    }

    // MARK: - Inactive Folded View

    @ViewBuilder
    private var inactiveFoldedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch block.kind {
            case .header(let level):
                renderHeader(level: level)

            case .bulletList(let indent):
                renderBulletList(indent: indent)

            case .numberedList(let index, let indent):
                renderNumberedList(index: index, indent: indent)

            case .taskList(let isChecked, let indent):
                renderTaskList(isChecked: isChecked, indent: indent)

            case .table(let data):
                MeridianMarkdownTableView(data: data, theme: document.theme) {
                    document.activateBlock(block.id)
                }

            case .blockquote(let indent):
                renderBlockquote(indent: indent)

            case .horizontalRule:
                Rectangle()
                    .fill(document.theme.dividerColor)
                    .frame(height: 1)
                    .padding(.vertical, 10)

            case .codeBlock(let language, let code):
                renderCodeBlock(language: language, code: code)

            case .paragraph:
                renderParagraph()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            document.activateBlock(block.id)
            #if os(macOS)
            NSApplication.shared.activate(ignoringOtherApps: true)
            #endif
        }
    }

    // MARK: - Block Renderers

    @ViewBuilder
    private func renderHeader(level: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            MeridianMarkdownInlineView(
                spans: block.inlineSpans,
                theme: document.theme,
                baseFont: headerFont(level: level),
                baseColor: headerColor(level: level)
            )

            // H1 bottom divider line spanning full width
            if level == 1 {
                Rectangle()
                    .fill(document.theme.dividerColor)
                    .frame(height: 1.2)
                    .padding(.top, 2)
            }
        }
        .padding(.top, level == 1 ? 14 : 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func renderBulletList(indent: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
                .font(document.theme.bodyFont.bold())
                .foregroundColor(document.theme.accentColor)
                .frame(width: 14, alignment: .trailing)

            MeridianMarkdownInlineView(spans: block.inlineSpans, theme: document.theme)
        }
        .padding(.leading, CGFloat(indent) * 16)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func renderNumberedList(index: Int, indent: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(index).")
                .font(document.theme.bodyFont.bold())
                .foregroundColor(document.theme.accentColor)
                .frame(minWidth: 18, alignment: .trailing)

            MeridianMarkdownInlineView(spans: block.inlineSpans, theme: document.theme)
        }
        .padding(.leading, CGFloat(indent) * 16)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func renderTaskList(isChecked: Bool, indent: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                document.toggleTask(blockId: block.id)
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(document.theme.accentColor)
            }
            .buttonStyle(.plain)

            MeridianMarkdownInlineView(
                spans: block.inlineSpans,
                theme: document.theme,
                baseColor: isChecked ? document.theme.text.opacity(0.5) : document.theme.text
            )
            .strikethrough(isChecked, color: document.theme.text.opacity(0.5))
        }
        .padding(.leading, CGFloat(indent) * 16)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func renderBlockquote(indent: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(document.theme.blockquoteColor)
                .frame(width: 3.5)

            MeridianMarkdownInlineView(
                spans: block.inlineSpans,
                theme: document.theme,
                baseFont: document.theme.bodyFont.italic(),
                baseColor: document.theme.text.opacity(0.85)
            )
        }
        .padding(.leading, CGFloat(indent) * 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func renderCodeBlock(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !language.isEmpty {
                HStack {
                    Spacer()
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(document.theme.text.opacity(0.5))
                }
            }
            Text(code.isEmpty ? " " : code)
                .font(document.theme.codeFont)
                .foregroundColor(document.theme.codeColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(document.theme.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func renderParagraph() -> some View {
        if block.rawText.isEmpty {
            Text(" ")
                .font(document.theme.bodyFont)
                .padding(.vertical, 2)
        } else {
            MeridianMarkdownInlineView(spans: block.inlineSpans, theme: document.theme)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Helpers

    private func headerFont(level: Int) -> Font {
        switch level {
        case 1: return document.theme.h1Font
        case 2: return document.theme.h2Font
        default: return document.theme.h3Font
        }
    }

    private func headerColor(level: Int) -> Color {
        switch level {
        case 1: return document.theme.h1Color
        case 2: return document.theme.h2Color
        default: return document.theme.h3Color
        }
    }

    private func themeFontForActiveKind(_ kind: MeridianBlockKind) -> Font {
        switch kind {
        case .header(let level): return headerFont(level: level)
        case .codeBlock: return document.theme.codeFont
        default: return document.theme.bodyFont
        }
    }
}

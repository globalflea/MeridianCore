//
// MeridianMarkdownEditor.swift
// MeridianUI
//
// Root SwiftUI editor container featuring the Obsidian-style top navigation bar,
// centered reading canvas with live-preview folding, and bottom analytics status bar.
//

import SwiftUI

/// Complete native Markdown editor with inline live-preview syntax folding.
///
/// Features a customizable theme, auto-continuing lists, GFM tables, and status analytics.
public struct MeridianMarkdownEditor: View {
    @Bindable public var document: MeridianMarkdownDocument

    /// Initializes the editor with an observable document.
    public init(document: MeridianMarkdownDocument) {
        self.document = document
    }

    public var body: some View {
        VStack(spacing: 0) {
            topNavigationBar

            Divider()
                .background(document.theme.dividerColor.opacity(0.4))

            canvasScrollView

            Divider()
                .background(document.theme.dividerColor.opacity(0.4))

            bottomStatusBar
        }
        .background(document.theme.background)
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            // Navigation chevrons
            HStack(spacing: 6) {
                Button(action: {}) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(document.theme.text.opacity(0.6))
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(document.theme.text.opacity(0.35))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Document Title
            TextField("Untitled", text: $document.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: document.theme.isSerif ? .serif : .default))
                .foregroundColor(document.theme.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Spacer()

            // Actions & View Options
            HStack(spacing: 10) {
                // Reader mode toggle
                Button(action: {
                    document.isReadOnly.toggle()
                    if document.isReadOnly {
                        document.deactivateActiveBlock()
                    }
                }) {
                    Image(systemName: document.isReadOnly ? "book.closed.fill" : "book")
                        .font(.system(size: 13))
                        .foregroundColor(document.isReadOnly ? document.theme.accentColor : document.theme.text.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Toggle Reader Mode")

                // Live Preview toggle
                Button(action: {
                    document.isLivePreviewEnabled.toggle()
                }) {
                    Image(systemName: document.isLivePreviewEnabled ? "eye" : "eye.slash")
                        .font(.system(size: 13))
                        .foregroundColor(document.isLivePreviewEnabled ? document.theme.accentColor : document.theme.text.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Toggle Live Preview")

                // Overflow / Insert Menu
                Menu {
                    Button("Insert Table") {
                        let activeIdx = document.blocks.firstIndex(where: { $0.id == document.activeBlockId }) ?? document.blocks.count
                        document.insertSampleTable(at: activeIdx + 1)
                    }

                    Menu("Theme") {
                        Button("Obsidian Sepia") { document.theme = .sepia }
                        Button("Apple Light") { document.theme = .light }
                        Button("Apple Dark") { document.theme = .dark }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(document.theme.text.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(document.theme.background)
    }

    // MARK: - Canvas Scroll View

    private var canvasScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(document.blocks) { block in
                    MeridianMarkdownBlockView(document: document, block: block)
                }

                // Tap target at the end of document to focus or spawn a line
                Color.clear
                    .frame(height: 120)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let last = document.blocks.last, last.rawText.isEmpty {
                            document.activateBlock(last.id)
                        } else {
                            let newBlock = MeridianMarkdownBlock(kind: .paragraph, rawText: "")
                            document.blocks.append(newBlock)
                            document.activateBlock(newBlock.id)
                        }
                    }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(document.theme.background)
    }

    // MARK: - Bottom Status Bar

    private var bottomStatusBar: some View {
        HStack(spacing: 12) {
            Text("0 backlinks")
                .font(.system(size: 11))
                .foregroundColor(document.theme.text.opacity(0.5))

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundColor(document.theme.text.opacity(0.45))

                Text("\(document.wordCount) words")
                    .font(.system(size: 11))
                    .foregroundColor(document.theme.text.opacity(0.55))

                Text("\(document.characterCount) characters")
                    .font(.system(size: 11))
                    .foregroundColor(document.theme.text.opacity(0.55))

                Image(systemName: document.isReadOnly ? "lock.fill" : "square.and.pencil")
                    .font(.system(size: 10))
                    .foregroundColor(document.theme.text.opacity(0.45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(document.theme.background)
    }
}

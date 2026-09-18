//
// main.swift
// MeridianMarkdownDemo
//
// Standalone macOS SwiftUI executable application for interactively trying out
// the MeridianMarkdownEditor live-preview component.
//

import SwiftUI
import MeridianUI
#if os(macOS)
import AppKit
#endif

/// Root entry point for the standalone macOS Markdown editor demo application.
@main
struct MeridianMarkdownDemoApp: App {

    init() {
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup("Meridian Markdown Live-Preview Editor") {
            MeridianMarkdownDemoContentView()
                .frame(minWidth: 920, minHeight: 720)
                .onAppear {
                    #if os(macOS)
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    DispatchQueue.main.async {
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }
                    #endif
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

/// Interactive container view providing the demo document and interactive controls.
public struct MeridianMarkdownDemoContentView: View {

    @State private var document = MeridianMarkdownDocument(
        initialMarkdown: MeridianMarkdownDemoContentView.sampleMarkdown,
        theme: .sepia
    )

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Instructions Banner
            HStack(spacing: 16) {
                Label("Obsidian Live-Preview Demo", systemImage: "pencil.and.outline")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Divider()
                    .frame(height: 16)

                Text("Click any block to edit raw syntax • Hit Enter to format & continue lists • Click checkboxes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    document.markdownText = MeridianMarkdownDemoContentView.sampleMarkdown
                    document.activeBlockId = nil
                } label: {
                    Label("Reset Sample", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            .overlay(alignment: .bottom) {
                Divider()
            }

            // Live-Preview Editor
            MeridianMarkdownEditor(document: document)
        }
    }

    /// Pre-loaded sample document demonstrating all Milestone 1 Markdown features.
    public static let sampleMarkdown: String = """
    # Meridian Markdown Live Preview
    Welcome to **MeridianMarkdownEditor**, an *Obsidian Live Preview* replica built natively in pure Swift 6 and SwiftUI.

    ## What Makes It Special
    - **Dual-State Live Preview**: Delimiters fold away into styled typography when you click away.
    - **Zero WebViews**: 100% native SwiftUI rendering with @Observable state management.
    - **Smart Continuations**: Bullet lists and numbered lists automatically continue on Enter.

    ### Interactive Task Checklist
    - [x] Native Swift 6 / SwiftUI component architecture
    - [x] Wine-red H1 with edge-to-edge dividing rule
    - [x] Terracotta H2 and scaled headings
    - [x] Cyan accent bullets and numbered auto-increment
    - [x] Interactive task checkboxes (click me to toggle!)
    - [x] GFM pipe tables with column alignment
    - [ ] Export to formatted PDF and HTML

    ### GFM Pipe Table Support
    | Technology | Role | Performance | Status |
    | :--- | :---: | ---: | :---: |
    | Swift 6 | Foundational Engine | < 1ms parse | Active |
    | SwiftUI | Declarative Vector Canvas | 60/120 FPS | Active |
    | SQLite WAL | Crash-Resilient Storage | Lock-free reads | Verified |

    ### Blockquotes & Code Blocks
    > "Simplicity is prerequisite for reliability."
    > — Edsger W. Dijkstra

    ```swift
    // Try editing this code block or adding new blocks below!
    let editor = MeridianMarkdownEditor(initialText: "# Hello World")
    ```

    1. First item in an ordered sequence
    2. Second item automatically incremented on Enter
    3. Try pressing Enter here to create item 4!
    """
}

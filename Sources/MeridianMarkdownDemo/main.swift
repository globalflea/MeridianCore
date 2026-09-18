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

    /// Pre-loaded sample document demonstrating all supported GitHub Flavored Markdown features.
    public static let sampleMarkdown: String = """
    # Meridian Markdown Live Preview
    Welcome to **MeridianMarkdownEditor**, an *Obsidian Live Preview* replica built natively in pure Swift 6 and SwiftUI.

    ## GitHub Flavored Markdown Callouts
    > [!NOTE]
    > Delimiters fold away into styled typography when you click away, and raw syntax expands on click.

    > [!TIP]
    > Click any block to edit — the insertion caret is placed precisely where you clicked without selecting all text!

    > [!IMPORTANT]
    > 100% native SwiftUI rendering with @Observable state management and zero WebViews.

    > [!WARNING]
    > Raw delimiter editing is interactive; press Enter on lists to automatically continue them.

    > [!CAUTION]
    > Deleting an empty list item with Backspace automatically reverts it back to a standard paragraph.

    ---

    ## GFM Pipe Tables with Escaped Pipes
    | Component | Specification | Status | Key Metric |
    | :--- | :---: | :---: | ---: |
    | **Parser** | GFM Compliance | `Active` | < 1ms parse |
    | **Live Preview** | Zero WebViews | `Native` | 60/120 FPS |
    | **Storage Engine** | SQLite WAL \\| B-Tree Index | `Verified` | Lock-free reads |
    | **UI Canvas** | SwiftUI Vector Stack | `Verified` | Sub-pixel layout |

    ---

    ### Interactive Task Checklist & Sub-Tasks
    - [x] Native Swift 6 / SwiftUI component architecture
    - [x] Wine-red H1 with edge-to-edge dividing rule
    - [x] Interactive task checkboxes (click me to toggle!)
      - [x] Nested sub-tasks with indentation
      - [ ] Real-time state persistence
    - [x] Precision caret positioning on click (no whole-block selection)
    - [ ] Export to formatted PDF and HTML

    ### Typographic Styling & Autolinks
    - Rich inline styles: **bold**, *italic*, ***bold italic***, and ~~strikethrough~~
    - Protected identifiers with underscores: `meridian_core_storage_v2` (immune to accidental italicization)
    - Autolinks: <https://github.com> and bare https://swift.org or [Meridian Docs](https://meridian.dev)
      1. First ordered item in a sequence
      2. Automatically incremented numbered list item
      3. Press Enter here to continue with item 4!

    ### Blockquotes & Code Blocks
    > "Simplicity is prerequisite for reliability."
    > — Edsger W. Dijkstra

    ```swift
    // Try editing this code block or adding new blocks below!
    let editor = MeridianMarkdownEditor(initialText: "# Hello World", theme: .sepia)
    ```

    ![Meridian Architecture Engine](https://raw.githubusercontent.com/globalflea/MeridianCore/main/Docs/Images/engine.png)
    """
}

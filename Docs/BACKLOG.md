# MeridianCore Backlog & Feature Register

This document tracks all planned, in-progress, and future feature items for the **`MeridianCore`** framework and its subsystem libraries, including **`MeridianUI`**.

---

## 1. Subsystem: `MeridianUI` — `MeridianMarkdownEditor` Feature Roadmap

Comprehensive implementation backlog derived from the canonical [Markdown Cheatsheet (Adam-P / CommonMark / GFM)](https://github.com/adam-p/markdown-here/wiki/markdown-cheatsheet) and Obsidian Live Preview interaction specifications.

### Priority Legend
- **P0 (Current Phase / Milestone 1)**: Core inline editing, live preview syntax folding, and daily essential Markdown syntax.
- **P1 (Milestone 2)**: Extended block containers, links, media, and task interactions.
- **P2 (Milestone 3)**: Advanced footnotes, HTML passthrough, reference links, and syntax highlight themes.

---

### Feature Register & Status Matrix

| ID | Category | Feature / Specification | Markdown Syntax Example | Priority | Status | Target Module |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **MD-01** | Headers | Atx-style Headings (H1 to H6) | `# H1` ... `###### H6` | **P0** | In Progress | `MeridianMarkdownParser` |
| **MD-02** | Headers | Setext-style Headings | `Alt-H1\n====` / `Alt-H2\n----` | **P1** | Planned | `MeridianMarkdownParser` |
| **MD-03** | Headers | Visual H1 dividing rule | Bottom border spanning container on H1 | **P0** | In Progress | `MeridianMarkdownBlockView` |
| **MD-04** | Emphasis | Inline Bold | `**bold**` or `__bold__` | **P0** | In Progress | `MeridianMarkdownInlineView` |
| **MD-05** | Emphasis | Inline Italics | `*italics*` or `_italics_` | **P0** | In Progress | `MeridianMarkdownInlineView` |
| **MD-06** | Emphasis | Combined Bold & Italics | `***bold-italic***` or `**_both_**` | **P0** | In Progress | `MeridianMarkdownInlineView` |
| **MD-07** | Emphasis | Strikethrough | `~~strikethrough text~~` | **P0** | In Progress | `MeridianMarkdownInlineView` |
| **MD-08** | Lists | Unordered Bullet Lists | `- item`, `* item`, `+ item` | **P0** | In Progress | `MeridianMarkdownBlockView` |
| **MD-09** | Lists | Ordered Numbered Lists | `1. item`, `2. item` | **P0** | In Progress | `MeridianMarkdownBlockView` |
| **MD-10** | Lists | Smart Enter List Continuation | Auto-insert `• ` or `n+1.` on Enter | **P0** | In Progress | `MeridianMarkdownDocument+Editing` |
| **MD-11** | Lists | Smart Backspace List Termination | Double Enter / Backspace clears empty bullet | **P0** | In Progress | `MeridianMarkdownDocument+Editing` |
| **MD-12** | Lists | Nested & Indented Sub-lists | 2-4 space or Tab indentation hierarchy | **P1** | Planned | `MeridianMarkdownBlockView` |
| **MD-13** | Task Lists | Interactive Checkboxes | `- [ ] unchecked`, `- [x] checked` | **P0** | In Progress | `MeridianMarkdownBlockView` |
| **MD-14** | Tables | GFM Pipe Tables | `\| Header \| Header \|\n\| --- \| --- \|` | **P0** | In Progress | `MeridianMarkdownTableView` |
| **MD-15** | Tables | Column Alignments | `:---` (Left), `:---:` (Center), `---:` (Right) | **P0** | In Progress | `MeridianMarkdownTableView` |
| **MD-16** | Tables | Formatted Cell Contents | Bold, italics, links, and code inside cells | **P1** | Planned | `MeridianMarkdownTableView` |
| **MD-17** | Blockquotes | Single & Multi-line Blockquotes | `> quoted text` | **P0** | In Progress | `MeridianMarkdownBlockView` |
| **MD-18** | Blockquotes | Nested Blockquotes | `> > nested quotation` | **P1** | Planned | `MeridianMarkdownBlockView` |
| **MD-19** | Horizontal Rules | Dividers / Page Breaks | `---`, `***`, or `___` | **P0** | In Progress | `MeridianMarkdownBlockView` |
| **MD-20** | Code | Inline Code | `` `inline code` `` | **P0** | In Progress | `MeridianMarkdownInlineView` |
| **MD-21** | Code | Fenced Code Blocks | ```` ```swift ... ``` ```` with lang identifier | **P0** | In Progress | `MeridianMarkdownBlockView` |
| **MD-22** | Code | Indented Code Blocks | 4 spaces or tab prefix | **P1** | Planned | `MeridianMarkdownParser` |
| **MD-23** | Links | Inline Links with Title | `[title](url "hover title")` | **P0** | In Progress | `MeridianMarkdownInlineView` |
| **MD-24** | Links | Autolinks & Raw URLs | `<https://apple.com>` or `https://apple.com` | **P1** | Planned | `MeridianMarkdownInlineView` |
| **MD-25** | Links | Reference-style Links | `[text][id]` + `[id]: url "title"` | **P2** | Planned | `MeridianMarkdownParser` |
| **MD-26** | Images | Inline Images | `![alt text](image-url "title")` | **P1** | Planned | `MeridianMarkdownBlockView` |
| **MD-27** | Images | Reference-style Images | `![alt][logo]` + `[logo]: url` | **P2** | Planned | `MeridianMarkdownParser` |
| **MD-28** | Footnotes | Footnote Citations & Definitions | `text[^1]` + `[^1]: Footnote body` | **P2** | Planned | `MeridianMarkdownParser` |
| **MD-29** | Inline HTML | Safe HTML tags & Entities | `<kbd>Cmd</kbd>`, `<sub>sub</sub>`, `<sup>sup</sup>` | **P2** | Planned | `MeridianMarkdownInlineView` |
| **MD-30** | Video Embeds | YouTube / Media link previews | `[![Alt](thumb)](video-url)` | **P2** | Planned | `MeridianMarkdownBlockView` |
| **MD-31** | Line Breaks | Soft & Hard Breaks | Two trailing spaces or backslash for `<br>` | **P1** | Planned | `MeridianMarkdownParser` |
| **MD-32** | Themes | Obsidian Sepia Preset | `#F3EDE3` background, warm wine & terracotta | **P0** | In Progress | `MeridianMarkdownTheme` |
| **MD-33** | Document Stats | Live Word & Character Counts | Real-time calculation in status bar | **P0** | In Progress | `MeridianMarkdownDocument` |

---

## 2. Milestone Architecture

### Milestone 1: Core Inline Markdown Engine (Active Scope)
- **Included**: MD-01, MD-03, MD-04, MD-05, MD-06, MD-07, MD-08, MD-09, MD-10, MD-11, MD-13, MD-14, MD-15, MD-17, MD-19, MD-20, MD-21, MD-23, MD-32, MD-33.
- **Verification**: Complete Swift Testing suite with $>95\%$ coverage across all files.

### Milestone 2: Extended Formatting, Nesting & Media
- **Included**: MD-02, MD-12, MD-16, MD-18, MD-22, MD-24, MD-26, MD-31.

### Milestone 3: Reference Citations, Footnotes & HTML Elements
- **Included**: MD-25, MD-27, MD-28, MD-29, MD-30.

### Milestone 4: TextKit 2 Single-Buffer Architecture (True CodeMirror 6 Parity)
- **Goal**: Full native Apple platform equivalent of CodeMirror 6's continuous-buffer live preview.
- **Core Architecture**:
  - Replace block-decoupled view trees with a single continuous text buffer backed by TextKit 2 (`NSTextContentStorage`, `NSTextLayoutManager`, `NSTextContainer`).
  - Single caret, uninterrupted multi-line drag selection, and native macOS spellcheck/IME/dictation.
  - In-place syntax folding via dynamic `NSAttributedString` attributes and custom `NSTextLayoutFragment`s.
  - Embedded interactive SwiftUI components (GFM tables, task checkboxes) via modern `NSTextAttachmentViewProvider`.
- **Architectural Decision**: Dropped WebKit/Electron bridge (Option 3) in favor of 100% pure native Swift & TextKit 2.

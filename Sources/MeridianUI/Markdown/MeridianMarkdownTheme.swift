//
// MeridianMarkdownTheme.swift
// MeridianUI
//
// Complete aesthetic styling tokens, color definitions, and typographic presets
// for the MeridianMarkdownEditor, including the Obsidian Sepia theme.
//

import SwiftUI

/// Typographic and visual color configuration for `MeridianMarkdownEditor`.
public struct MeridianMarkdownTheme: Sendable, Hashable, Equatable {
    /// Canvas page background color.
    public var background: Color

    /// Primary body text color.
    public var text: Color

    /// Level 1 Heading color.
    public var h1Color: Color

    /// Level 2 Heading color.
    public var h2Color: Color

    /// Level 3 Heading color.
    public var h3Color: Color

    /// Accent color for list bullets, ordered list numbers, and hyperlinks.
    public var accentColor: Color

    /// Strong emphasis (`**bold**`) color.
    public var boldColor: Color

    /// Emphasis (`*italic*`) color.
    public var italicColor: Color

    /// Monospace inline and block code text color.
    public var codeColor: Color

    /// Code background pill/card tint.
    public var codeBackground: Color

    /// Blockquote left indicator border and text tint.
    public var blockquoteColor: Color

    /// Horizontal rule and H1 underline divider color.
    public var dividerColor: Color

    /// Table header row background fill.
    public var tableHeaderBackground: Color

    /// Table outer and internal grid border color.
    public var tableBorderColor: Color

    /// Color applied to visible markdown delimiter tokens when a block is active.
    public var syntaxTokenColor: Color

    /// Whether headings and body text render with elegant Serif typography.
    public var isSerif: Bool

    /// Creates a custom markdown theme.
    public init(
        background: Color,
        text: Color,
        h1Color: Color,
        h2Color: Color,
        h3Color: Color,
        accentColor: Color,
        boldColor: Color,
        italicColor: Color,
        codeColor: Color,
        codeBackground: Color,
        blockquoteColor: Color,
        dividerColor: Color,
        tableHeaderBackground: Color,
        tableBorderColor: Color,
        syntaxTokenColor: Color,
        isSerif: Bool = true
    ) {
        self.background = background
        self.text = text
        self.h1Color = h1Color
        self.h2Color = h2Color
        self.h3Color = h3Color
        self.accentColor = accentColor
        self.boldColor = boldColor
        self.italicColor = italicColor
        self.codeColor = codeColor
        self.codeBackground = codeBackground
        self.blockquoteColor = blockquoteColor
        self.dividerColor = dividerColor
        self.tableHeaderBackground = tableHeaderBackground
        self.tableBorderColor = tableBorderColor
        self.syntaxTokenColor = syntaxTokenColor
        self.isSerif = isSerif
    }

    /// Font for Level 1 Headings.
    public var h1Font: Font {
        isSerif
            ? .system(size: 28, weight: .bold, design: .serif)
            : .system(size: 28, weight: .bold, design: .default)
    }

    /// Font for Level 2 Headings.
    public var h2Font: Font {
        isSerif
            ? .system(size: 22, weight: .bold, design: .serif)
            : .system(size: 22, weight: .bold, design: .default)
    }

    /// Font for Level 3 Headings.
    public var h3Font: Font {
        isSerif
            ? .system(size: 18, weight: .bold, design: .serif)
            : .system(size: 18, weight: .bold, design: .default)
    }

    /// Font for Body and Paragraphs.
    public var bodyFont: Font {
        isSerif
            ? .system(size: 15, weight: .regular, design: .serif)
            : .system(size: 15, weight: .regular, design: .default)
    }

    /// Font for Monospace Code.
    public var codeFont: Font {
        .system(size: 13, weight: .medium, design: .monospaced)
    }
}

public extension MeridianMarkdownTheme {
    /// Warm sepia theme matching the Obsidian Live Preview recording.
    static let sepia = MeridianMarkdownTheme(
        background: Color(red: 0.953, green: 0.933, blue: 0.890),
        text: Color(red: 0.180, green: 0.176, blue: 0.170),
        h1Color: Color(red: 0.549, green: 0.231, blue: 0.263),
        h2Color: Color(red: 0.816, green: 0.404, blue: 0.220),
        h3Color: Color(red: 0.420, green: 0.298, blue: 0.447),
        accentColor: Color(red: 0.169, green: 0.541, blue: 0.722),
        boldColor: Color(red: 0.549, green: 0.231, blue: 0.263),
        italicColor: Color(red: 0.239, green: 0.471, blue: 0.306),
        codeColor: Color(red: 0.760, green: 0.300, blue: 0.350),
        codeBackground: Color(red: 0.910, green: 0.880, blue: 0.830),
        blockquoteColor: Color(red: 0.550, green: 0.520, blue: 0.480),
        dividerColor: Color(red: 0.549, green: 0.231, blue: 0.263).opacity(0.35),
        tableHeaderBackground: Color(red: 0.910, green: 0.880, blue: 0.830),
        tableBorderColor: Color(red: 0.840, green: 0.800, blue: 0.740),
        syntaxTokenColor: Color(red: 0.549, green: 0.231, blue: 0.263).opacity(0.70),
        isSerif: true
    )

    /// Clean, modern Apple light mode theme.
    static let light = MeridianMarkdownTheme(
        background: Color(white: 0.98),
        text: Color.primary,
        h1Color: Color.blue,
        h2Color: Color.indigo,
        h3Color: Color.purple,
        accentColor: Color.blue,
        boldColor: Color.primary,
        italicColor: Color.secondary,
        codeColor: Color.pink,
        codeBackground: Color(white: 0.93),
        blockquoteColor: Color.gray,
        dividerColor: Color.gray.opacity(0.3),
        tableHeaderBackground: Color(white: 0.94),
        tableBorderColor: Color.gray.opacity(0.35),
        syntaxTokenColor: Color.secondary.opacity(0.7),
        isSerif: false
    )

    /// Sleek, high-contrast Apple dark mode theme.
    static let dark = MeridianMarkdownTheme(
        background: Color(red: 0.12, green: 0.12, blue: 0.13),
        text: Color(white: 0.92),
        h1Color: Color(red: 0.4, green: 0.7, blue: 1.0),
        h2Color: Color(red: 0.95, green: 0.65, blue: 0.35),
        h3Color: Color(red: 0.75, green: 0.55, blue: 0.9),
        accentColor: Color(red: 0.35, green: 0.75, blue: 0.95),
        boldColor: Color(white: 0.98),
        italicColor: Color(red: 0.45, green: 0.85, blue: 0.6),
        codeColor: Color(red: 1.0, green: 0.55, blue: 0.65),
        codeBackground: Color(white: 0.18),
        blockquoteColor: Color(white: 0.55),
        dividerColor: Color(white: 0.25),
        tableHeaderBackground: Color(white: 0.18),
        tableBorderColor: Color(white: 0.28),
        syntaxTokenColor: Color(white: 0.5),
        isSerif: false
    )

    // MARK: - Block Kind Typography Resolution

    /// Returns the appropriate header font for an ATX header level (1-6).
    func headerFont(level: Int) -> Font {
        level == 1 ? h1Font : (level == 2 ? h2Font : h3Font)
    }

    /// Returns the appropriate header text color for an ATX header level (1-6).
    func headerColor(level: Int) -> Color {
        level == 1 ? h1Color : (level == 2 ? h2Color : h3Color)
    }

    /// Resolves the editing font for an active block kind.
    func fontForBlockKind(_ kind: MeridianBlockKind) -> Font {
        switch kind {
        case .header(let level): return headerFont(level: level)
        case .codeBlock: return codeFont
        default: return bodyFont
        }
    }
}

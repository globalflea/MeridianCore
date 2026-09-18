//
// MeridianMarkdownInlineView.swift
// MeridianUI
//
// Formatted inline typographical rendering engine combining multiple spans into
// wrapped, beautifully styled SwiftUI Text with bold, italic, code, and links.
//

import SwiftUI

/// Renders a collection of parsed inline Markdown spans with theme-aware typography.
public struct MeridianMarkdownInlineView: View {
    public let spans: [MeridianInlineSpan]
    public let theme: MeridianMarkdownTheme
    public var baseFont: Font?
    public var baseColor: Color?

    /// Initializes the inline span view.
    public init(
        spans: [MeridianInlineSpan],
        theme: MeridianMarkdownTheme,
        baseFont: Font? = nil,
        baseColor: Color? = nil
    ) {
        self.spans = spans
        self.theme = theme
        self.baseFont = baseFont
        self.baseColor = baseColor
    }

    public var body: some View {
        if spans.isEmpty {
            Text("")
        } else {
            spans.reduce(Text("")) { accumulated, span in
                accumulated + styledText(for: span)
            }
        }
    }

    private func styledText(for span: MeridianInlineSpan) -> Text {
        let font = baseFont ?? theme.bodyFont
        let defaultColor = baseColor ?? theme.text

        switch span {
        case .plain(let string):
            return Text(string)
                .font(font)
                .foregroundColor(defaultColor)

        case .bold(let string):
            return Text(string)
                .font(font.bold())
                .foregroundColor(theme.boldColor)

        case .italic(let string):
            return Text(string)
                .font(font.italic())
                .foregroundColor(theme.italicColor)

        case .boldItalic(let string):
            return Text(string)
                .font(font.bold().italic())
                .foregroundColor(theme.boldColor)

        case .strikethrough(let string):
            return Text(string)
                .font(font)
                .strikethrough(true, color: defaultColor.opacity(0.6))
                .foregroundColor(defaultColor.opacity(0.6))

        case .inlineCode(let string):
            return Text(string)
                .font(theme.codeFont)
                .foregroundColor(theme.codeColor)

        case .link(let text, _):
            return Text(text)
                .font(font)
                .underline()
                .foregroundColor(theme.accentColor)

        case .image(let alt, _):
            return Text("🖼️ \(alt)")
                .font(font)
                .foregroundColor(theme.accentColor)
        }
    }
}

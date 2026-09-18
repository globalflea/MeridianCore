//
// MeridianMarkdownCalloutView.swift
// MeridianUI
//
// Modern GitHub alert callout component rendering themed notification cards
// for [!NOTE], [!TIP], [!IMPORTANT], [!WARNING], and [!CAUTION] annotations.
//

import SwiftUI

/// Renders a modern GitHub alert callout card with icon, title, and formatted markdown body.
public struct MeridianMarkdownCalloutView: View {
    public let kind: MeridianAlertKind
    public let content: String
    public let theme: MeridianMarkdownTheme

    /// Initializes a callout card view.
    public init(
        kind: MeridianAlertKind,
        content: String,
        theme: MeridianMarkdownTheme
    ) {
        self.kind = kind
        self.content = content
        self.theme = theme
    }

    /// Accent color associated with this alert category.
    public var accentColor: Color {
        switch kind {
        case .note: return .blue
        case .tip: return .green
        case .important: return .purple
        case .warning: return .orange
        case .caution: return .red
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left vertical accent stripe
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 3.5)

            VStack(alignment: .leading, spacing: 6) {
                // Header banner: Icon + Title
                HStack(spacing: 6) {
                    Image(systemName: kind.iconSystemName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)

                    Text(kind.title)
                        .font(theme.bodyFont.bold())
                        .foregroundColor(accentColor)
                }

                // Inner content
                let spans = MeridianMarkdownParser.parseInlineSpans(text: content)
                MeridianMarkdownInlineView(
                    spans: spans,
                    theme: theme,
                    baseFont: theme.bodyFont,
                    baseColor: theme.text
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.trailing, 10)
        }
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 4)
    }
}

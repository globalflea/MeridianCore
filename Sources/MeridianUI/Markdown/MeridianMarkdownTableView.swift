//
// MeridianMarkdownTableView.swift
// MeridianUI
//
// Declarative SwiftUI table view rendering GFM Markdown tables with theme-aware styling,
// column alignment, and rounded-corner borders.
//

import SwiftUI

/// Declarative visual table rendering for GitHub Flavored Markdown (GFM) pipe tables.
public struct MeridianMarkdownTableView: View {
    public let data: MeridianTableData
    public let theme: MeridianMarkdownTheme
    public var onSelect: (@MainActor @Sendable () -> Void)?

    /// Creates a formatted table view.
    public init(
        data: MeridianTableData,
        theme: MeridianMarkdownTheme,
        onSelect: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.data = data
        self.theme = theme
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Row
            if !data.headers.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(data.headers.enumerated()), id: \.offset) { index, header in
                        let alignment = data.alignment(for: index)
                        let headerSpans = MeridianMarkdownParser.parseInlineSpans(text: header)
                        MeridianMarkdownInlineView(
                            spans: headerSpans,
                            theme: theme,
                            baseFont: theme.bodyFont.bold()
                        )
                        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)

                        if index < data.headers.count - 1 {
                            Divider()
                                .background(theme.tableBorderColor)
                        }
                    }
                }
                .background(theme.tableHeaderBackground)

                Divider()
                    .background(theme.tableBorderColor)
            }

            // Data Rows
            ForEach(Array(data.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(0..<data.columnCount, id: \.self) { colIndex in
                        let cellText = colIndex < row.count ? row[colIndex] : ""
                        let alignment = data.alignment(for: colIndex)
                        let cellSpans = MeridianMarkdownParser.parseInlineSpans(text: cellText)

                        MeridianMarkdownInlineView(
                            spans: cellSpans,
                            theme: theme,
                            baseFont: theme.bodyFont
                        )
                        .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)

                        if colIndex < data.columnCount - 1 {
                            Divider()
                                .background(theme.tableBorderColor.opacity(0.6))
                        }
                    }
                }
                .background(rowIndex % 2 == 1 ? theme.tableHeaderBackground.opacity(0.35) : Color.clear)

                if rowIndex < data.rows.count - 1 {
                    Divider()
                        .background(theme.tableBorderColor.opacity(0.5))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.tableBorderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .padding(.vertical, 6)
    }
}

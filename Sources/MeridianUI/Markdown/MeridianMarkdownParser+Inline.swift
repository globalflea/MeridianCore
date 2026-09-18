//
// MeridianMarkdownParser+Inline.swift
// MeridianUI
//
// Tokenizer for rich inline Markdown spans (bold, italic, inline code, strikethrough, links).
//

import Foundation

extension MeridianMarkdownParser {

    /// Scans text and splits into rich formatting spans (`**bold**`, `*italic*`, etc.).
    ///
    /// - Parameter text: Raw unformatted string within a block.
    /// - Returns: Ordered array of `MeridianInlineSpan` tokens.
    public static func parseInlineSpans(text: String) -> [MeridianInlineSpan] {
        guard !text.isEmpty else { return [] }
        var spans: [MeridianInlineSpan] = []
        var remainder = Substring(text)

        while !remainder.isEmpty {
            // Check for Bold Italic: ***text***
            if let match = matchDelimited(remainder, delimiter: "***") {
                spans.append(.boldItalic(match.content))
                remainder = match.remainder
                continue
            }
            // Check for Bold: **text**
            if let match = matchDelimited(remainder, delimiter: "**") {
                spans.append(.bold(match.content))
                remainder = match.remainder
                continue
            }
            // Check for Inline Code: `code`
            if let match = matchDelimited(remainder, delimiter: "`") {
                spans.append(.inlineCode(match.content))
                remainder = match.remainder
                continue
            }
            // Check for Strikethrough: ~~text~~
            if let match = matchDelimited(remainder, delimiter: "~~") {
                spans.append(.strikethrough(match.content))
                remainder = match.remainder
                continue
            }
            // Check for Italic: *text* or _text_
            if let match = matchDelimited(remainder, delimiter: "*") {
                spans.append(.italic(match.content))
                remainder = match.remainder
                continue
            }
            // Check for Link: [text](url)
            if let match = matchLink(remainder) {
                spans.append(.link(text: match.title, url: match.url))
                remainder = match.remainder
                continue
            }

            // Normal character: consume until next potential markdown delimiter
            var plainEnd = remainder.startIndex
            var nextIndex = remainder.index(after: plainEnd)
            while nextIndex < remainder.endIndex {
                let char = remainder[nextIndex]
                if char == "*" || char == "`" || char == "~" || char == "[" {
                    break
                }
                plainEnd = nextIndex
                nextIndex = remainder.index(after: nextIndex)
            }

            let plainSegment = String(remainder[...plainEnd])
            spans.append(.plain(plainSegment))
            remainder = remainder[remainder.index(after: plainEnd)...]
        }

        return spans
    }

    private static func matchDelimited(_ text: Substring, delimiter: String) -> (content: String, remainder: Substring)? {
        guard text.hasPrefix(delimiter) else { return nil }
        let afterStart = text.dropFirst(delimiter.count)
        guard let closingRange = afterStart.range(of: delimiter) else { return nil }
        let content = String(afterStart[..<closingRange.lowerBound])
        guard !content.isEmpty else { return nil }
        let remainder = afterStart[closingRange.upperBound...]
        return (content, remainder)
    }

    private static func matchLink(_ text: Substring) -> (title: String, url: String, remainder: Substring)? {
        guard text.hasPrefix("[") else { return nil }
        guard let closeBracket = text.firstIndex(of: "]") else { return nil }
        let titleStart = text.index(after: text.startIndex)
        let title = String(text[titleStart..<closeBracket])

        let rest = text[closeBracket...]
        guard rest.hasPrefix("](") else { return nil }
        let afterOpenParen = rest.dropFirst(2)
        guard let closeParen = afterOpenParen.firstIndex(of: ")") else { return nil }
        let url = String(afterOpenParen[..<closeParen])
        let remainder = afterOpenParen[afterOpenParen.index(after: closeParen)...]
        return (title, url, remainder)
    }
}

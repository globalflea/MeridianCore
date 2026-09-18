//
// MeridianMarkdownParser+Inline.swift
// MeridianUI
//
// Tokenizer for rich inline Markdown spans (bold, italic, code, strikethrough, links, autolinks, images)
// adhering to GFM §6 rules including underscore intra-word delimiter protection.
//

import Foundation

extension MeridianMarkdownParser {

    /// Scans text and splits into rich formatting spans (`**bold**`, `*italic*`, `_italic_`, links, etc.).
    ///
    /// - Parameter text: Raw unformatted string within a block.
    /// - Returns: Ordered array of `MeridianInlineSpan` tokens.
    public static func parseInlineSpans(text: String) -> [MeridianInlineSpan] {
        guard !text.isEmpty else { return [] }
        var spans: [MeridianInlineSpan] = []
        var remainder = Substring(text)

        while !remainder.isEmpty {
            // 1. Image: ![alt](url) - must check before link
            if let match = matchImage(remainder) {
                spans.append(.image(alt: match.alt, url: match.url))
                remainder = match.remainder
                continue
            }

            // 2. Link: [text](url)
            if let match = matchLink(remainder) {
                spans.append(.link(text: match.title, url: match.url))
                remainder = match.remainder
                continue
            }

            // 3. Angle-bracket autolink: <https://...> or <user@example.com>
            if let match = matchAngleAutolink(remainder) {
                spans.append(.link(text: match.text, url: match.url))
                remainder = match.remainder
                continue
            }

            // 4. Bare autolink: https://..., http://..., www....
            if let match = matchBareAutolink(remainder) {
                spans.append(.link(text: match.text, url: match.url))
                remainder = match.remainder
                continue
            }

            // 5. Asterisk Bold-Italic: ***text***
            if let match = matchDelimited(remainder, delimiter: "***") {
                spans.append(.boldItalic(match.content))
                remainder = match.remainder
                continue
            }

            // 6. Underscore Bold-Italic: ___text___ (with intra-word protection)
            if let match = matchUnderscore(fullText: text, text: remainder, delimiter: "___") {
                spans.append(.boldItalic(match.content))
                remainder = match.remainder
                continue
            }

            // 7. Asterisk Bold: **text**
            if let match = matchDelimited(remainder, delimiter: "**") {
                spans.append(.bold(match.content))
                remainder = match.remainder
                continue
            }

            // 8. Underscore Bold: __text__ (with intra-word protection)
            if let match = matchUnderscore(fullText: text, text: remainder, delimiter: "__") {
                spans.append(.bold(match.content))
                remainder = match.remainder
                continue
            }

            // 9. Inline Code: `code`
            if let match = matchDelimited(remainder, delimiter: "`") {
                spans.append(.inlineCode(match.content))
                remainder = match.remainder
                continue
            }

            // 10. Strikethrough: ~~text~~
            if let match = matchDelimited(remainder, delimiter: "~~") {
                spans.append(.strikethrough(match.content))
                remainder = match.remainder
                continue
            }

            // 11. Asterisk Italic: *text*
            if let match = matchDelimited(remainder, delimiter: "*") {
                spans.append(.italic(match.content))
                remainder = match.remainder
                continue
            }

            // 12. Underscore Italic: _text_ (with intra-word protection)
            if let match = matchUnderscore(fullText: text, text: remainder, delimiter: "_") {
                spans.append(.italic(match.content))
                remainder = match.remainder
                continue
            }

            // Normal character: consume until next potential markdown delimiter
            var plainEnd = remainder.startIndex
            var nextIndex = remainder.index(after: plainEnd)
            while nextIndex < remainder.endIndex {
                let char = remainder[nextIndex]
                if char == "_" {
                    let prev = remainder[plainEnd]
                    if !prev.isLetter && !prev.isNumber {
                        break
                    }
                } else if char == "*" || char == "`" || char == "~" ||
                          char == "[" || char == "!" || char == "<" {
                    break
                }
                let sub = remainder[nextIndex...]
                if sub.hasPrefix("https://") || sub.hasPrefix("http://") || sub.hasPrefix("www.") {
                    break
                }
                plainEnd = nextIndex
                nextIndex = remainder.index(after: nextIndex)
            }

            let plainSegment = String(remainder[...plainEnd])
            if let last = spans.last, case .plain(let prevStr) = last {
                spans[spans.count - 1] = .plain(prevStr + plainSegment)
            } else {
                spans.append(.plain(plainSegment))
            }
            remainder = remainder[remainder.index(after: plainEnd)...]
        }

        return spans
    }

    private static func matchDelimited(_ text: Substring, delimiter: String) -> (content: String, remainder: Substring)? {
        guard text.hasPrefix(delimiter) else { return nil }
        let afterStart = text.dropFirst(delimiter.count)
        guard let firstChar = afterStart.first, !firstChar.isWhitespace else { return nil }
        guard let closingRange = afterStart.range(of: delimiter) else { return nil }
        let content = String(afterStart[..<closingRange.lowerBound])
        guard !content.isEmpty, let lastChar = content.last, !lastChar.isWhitespace else { return nil }
        let remainder = afterStart[closingRange.upperBound...]
        return (content, remainder)
    }

    private static func matchUnderscore(fullText: String, text: Substring, delimiter: String) -> (content: String, remainder: Substring)? {
        guard text.hasPrefix(delimiter) else { return nil }

        // Intra-word check for opening delimiter: cannot be preceded by a word character
        if text.startIndex > fullText.startIndex {
            let prevIndex = fullText.index(before: text.startIndex)
            let prevChar = fullText[prevIndex]
            if prevChar.isLetter || prevChar.isNumber { return nil }
        }

        let afterStart = text.dropFirst(delimiter.count)
        guard let firstChar = afterStart.first, !firstChar.isWhitespace, firstChar != "_" else { return nil }
        guard let closingRange = afterStart.range(of: delimiter) else { return nil }

        let content = String(afterStart[..<closingRange.lowerBound])
        guard !content.isEmpty, let lastChar = content.last, !lastChar.isWhitespace, lastChar != "_" else { return nil }

        // Intra-word check for closing delimiter: cannot be followed by a word character
        let afterClose = afterStart[closingRange.upperBound...]
        if let nextChar = afterClose.first, nextChar.isLetter || nextChar.isNumber {
            return nil
        }

        return (content, afterClose)
    }

    private static func matchImage(_ text: Substring) -> (alt: String, url: String, remainder: Substring)? {
        guard text.hasPrefix("![") else { return nil }
        let inner = text.dropFirst(1) // Keep '['
        guard let link = matchLink(inner) else { return nil }
        return (link.title, link.url, link.remainder)
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

    private static func matchAngleAutolink(_ text: Substring) -> (text: String, url: String, remainder: Substring)? {
        guard text.hasPrefix("<") else { return nil }
        guard let closeAngle = text.firstIndex(of: ">") else { return nil }
        let innerStart = text.index(after: text.startIndex)
        let inner = String(text[innerStart..<closeAngle])

        if inner.hasPrefix("http://") || inner.hasPrefix("https://") {
            let remainder = text[text.index(after: closeAngle)...]
            return (inner, inner, remainder)
        } else if inner.contains("@") && !inner.contains(" ") {
            let remainder = text[text.index(after: closeAngle)...]
            let url = inner.hasPrefix("mailto:") ? inner : "mailto:\(inner)"
            return (inner, url, remainder)
        }
        return nil
    }

    private static func matchBareAutolink(_ text: Substring) -> (text: String, url: String, remainder: Substring)? {
        var prefixLen = 0
        var isWWW = false
        if text.hasPrefix("https://") {
            prefixLen = 8
        } else if text.hasPrefix("http://") {
            prefixLen = 7
        } else if text.hasPrefix("www.") {
            prefixLen = 4
            isWWW = true
        } else {
            return nil
        }

        var endIdx = text.index(text.startIndex, offsetBy: prefixLen)
        while endIdx < text.endIndex {
            let ch = text[endIdx]
            if ch.isWhitespace || ch == "<" || ch == ">" || ch == "\"" || ch == "'" {
                break
            }
            endIdx = text.index(after: endIdx)
        }

        // Trim trailing punctuation per GFM §6.9 (period, comma, question, exclamation, closing paren/bracket)
        var urlSubstring = text[text.startIndex..<endIdx]
        while let last = urlSubstring.last, last == "." || last == "," || last == "?" || last == "!" || last == ")" || last == "]" {
            urlSubstring = urlSubstring.dropLast()
        }

        guard urlSubstring.count > prefixLen else { return nil }
        let raw = String(urlSubstring)
        let targetUrl = isWWW ? "http://\(raw)" : raw
        let remainder = text[urlSubstring.endIndex...]
        return (raw, targetUrl, remainder)
    }
}


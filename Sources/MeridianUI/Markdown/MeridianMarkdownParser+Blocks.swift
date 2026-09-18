//
// MeridianMarkdownParser+Blocks.swift
// MeridianUI
//
// Block-level parsing helpers for thematic breaks, standalone images, GitHub alerts, and list markers.
//

import Foundation

extension MeridianMarkdownParser {

    /// Detects whether a string is a valid GFM §4.1 thematic break (`---`, `----`, `* * *`, `_ _ _ _`).
    public static func isThematicBreak(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let nonSpace = trimmed.filter { !$0.isWhitespace }
        guard nonSpace.count >= 3 else { return false }
        guard let first = nonSpace.first, first == "-" || first == "*" || first == "_" else { return false }
        return nonSpace.allSatisfy { $0 == first }
    }

    /// Detects a standalone image block `![alt](url)`.
    public static func parseImageBlock(_ trimmed: String) -> (alt: String, url: String)? {
        guard trimmed.hasPrefix("![") && trimmed.hasSuffix(")") else { return nil }
        guard let closeBracket = trimmed.firstIndex(of: "]") else { return nil }
        let rest = trimmed[closeBracket...]
        guard rest.hasPrefix("](") else { return nil }
        let alt = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<closeBracket])
        let urlStart = trimmed.index(closeBracket, offsetBy: 2)
        let urlEnd = trimmed.index(before: trimmed.endIndex)
        guard urlStart <= urlEnd else { return nil }
        let url = String(trimmed[urlStart..<urlEnd]).trimmingCharacters(in: .whitespaces)
        return (alt, url)
    }

    /// Detects modern GitHub alert callouts: `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`.
    public static func parseAlertCallout(_ inner: String) -> (kind: MeridianAlertKind, content: String)? {
        guard inner.hasPrefix("[!") else { return nil }
        guard let closeBracket = inner.firstIndex(of: "]") else { return nil }
        let tagStart = inner.index(inner.startIndex, offsetBy: 2)
        let tag = inner[tagStart..<closeBracket].lowercased()
        guard let kind = MeridianAlertKind(rawValue: tag) else { return nil }

        let afterTag = inner[inner.index(after: closeBracket)...]
        let content = afterTag.trimmingCharacters(in: .whitespaces)
        return (kind, content)
    }

    /// Detects task item checkboxes: `- [ ]`, `* [ ]`, `+ [ ]`, `- [x]`, `* [x]`, `+ [x]`, `1. [ ]`.
    public static func parseTaskPrefix(_ trimmed: String) -> (isChecked: Bool, content: String)? {
        let prefixes: [(prefix: String, isChecked: Bool)] = [
            ("- [ ] ", false), ("* [ ] ", false), ("+ [ ] ", false),
            ("- [x] ", true),  ("* [x] ", true),  ("+ [x] ", true),
            ("- [X] ", true),  ("* [X] ", true),  ("+ [X] ", true)
        ]

        for p in prefixes {
            if trimmed.hasPrefix(p.prefix) {
                let content = String(trimmed.dropFirst(p.prefix.count))
                return (p.isChecked, content)
            }
        }

        // Ordered task items: e.g. "1. [ ] " or "1. [x] "
        if let (number, afterNumber) = parseNumberedListPrefix(trimmed) {
            let taskPart = afterNumber.trimmingCharacters(in: .whitespaces)
            if taskPart.hasPrefix("[ ] ") {
                let content = "\(number). " + String(taskPart.dropFirst(4))
                return (false, content)
            } else if taskPart.hasPrefix("[x] ") || taskPart.hasPrefix("[X] ") {
                let content = "\(number). " + String(taskPart.dropFirst(4))
                return (true, content)
            }
        }

        return nil
    }

    /// Parses ordered list numeric prefixes like `1. ` or `1) ` (GFM §5.2).
    public static func parseNumberedListPrefix(_ line: String) -> (Int, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var digits = ""
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex && trimmed[idx].isNumber {
            digits.append(trimmed[idx])
            idx = trimmed.index(after: idx)
        }
        guard !digits.isEmpty, let number = Int(digits), idx < trimmed.endIndex else { return nil }
        guard trimmed[idx] == "." || trimmed[idx] == ")" else { return nil }
        idx = trimmed.index(after: idx)
        if idx == trimmed.endIndex {
            return (number, "")
        }
        guard trimmed[idx] == " " else { return nil }
        let content = String(trimmed[trimmed.index(after: idx)...])
        return (number, content)
    }
}

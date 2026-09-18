//
// MeridianMarkdownCaretCoordinator.swift
// MeridianUI
//
// AppKit and cross-platform text focus coordinator ensuring that activating a block
// never highlights or selects the entire text string, instead placing an insertion
// caret directly at the clicked mouse coordinates or end of text.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Coordinates text selection and caret insertion when Markdown blocks transition into active edit mode.
public struct MeridianMarkdownCaretCoordinator: Sendable {

    #if os(macOS)
    /// Collapses any active text selection in the window's first responder to a zero-length insertion caret.
    ///
    /// - Parameters:
    ///   - window: The target window hosting the editor (defaults to `NSApp.keyWindow`).
    ///   - preferredLocation: Optional local coordinate of the mouse click within the block view.
    @MainActor
    public static func collapseSelectionToCaret(
        in window: NSWindow? = nil,
        preferredLocation: CGPoint? = nil
    ) {
        let win = window
            ?? NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first(where: { $0.isKeyWindow })
            ?? NSApplication.shared.windows.first

        guard let targetWindow = win,
              let textView = targetWindow.firstResponder as? NSTextView else {
            return
        }

        let totalLength = (textView.string as NSString).length
        guard totalLength > 0 else {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            return
        }

        let targetIndex: Int
        let mouseInWindow = targetWindow.mouseLocationOutsideOfEventStream
        let mouseInTextView = textView.convert(mouseInWindow, from: nil)

        if textView.bounds.contains(mouseInTextView) {
            targetIndex = characterIndex(for: mouseInTextView, in: textView)
        } else if let location = preferredLocation {
            // Adjust for block view inner padding (horizontal: 6, vertical: 3)
            let adjustedPoint = NSPoint(x: max(0, location.x - 6), y: max(0, location.y - 3))
            targetIndex = characterIndex(for: adjustedPoint, in: textView)
        } else {
            targetIndex = totalLength
        }

        let clampedIndex = min(max(0, targetIndex), totalLength)
        textView.setSelectedRange(NSRange(location: clampedIndex, length: 0))
    }

    /// Resolves the character insertion index closest to a given point inside an `NSTextView`.
    ///
    /// - Parameters:
    ///   - point: The coordinates in the `NSTextView`'s local coordinate system.
    ///   - textView: The active AppKit text view.
    /// - Returns: Zero-based character index for caret insertion.
    @MainActor
    public static func characterIndex(for point: NSPoint, in textView: NSTextView) -> Int {
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
            return layoutManager.characterIndexForGlyph(at: glyphIndex)
        }
        return (textView.string as NSString).length
    }
    #endif

    /// Pure-function character index estimator used for headless tests and coordinate fallback.
    ///
    /// - Parameters:
    ///   - point: Local coordinate within the text block.
    ///   - text: The block's raw text.
    ///   - averageCharWidth: Estimated average character width in points (default: 8.0).
    ///   - lineHeight: Estimated line height in points (default: 20.0).
    /// - Returns: Clamped character offset in the string.
    public static func estimateCharacterIndex(
        for point: CGPoint,
        in text: String,
        averageCharWidth: CGFloat = 8.0,
        lineHeight: CGFloat = 20.0
    ) -> Int {
        guard !text.isEmpty else { return 0 }
        let lines = text.components(separatedBy: "\n")
        let targetLine = min(max(0, Int(point.y / max(lineHeight, 1.0))), lines.count - 1)
        let targetCol = max(0, Int(point.x / max(averageCharWidth, 1.0)))

        var accumulated = 0
        for i in 0..<targetLine {
            accumulated += lines[i].count + 1
        }
        let lineLength = lines[targetLine].count
        let colOffset = min(targetCol, lineLength)
        return min(accumulated + colOffset, text.count)
    }
}

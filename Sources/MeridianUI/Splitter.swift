// Copyright (c) 2026 the Meridian project authors
//
// Splitter.swift
// MeridianUI
//
// Universal draggable divider line for multi-pane containers and modular workstations.
// Features an expanded hit-testing target, hover accent illumination, cursor management,
// and double-click reset support.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Layout orientation for a `Splitter`.
public enum SplitterOrientation: Sendable, Equatable {
    /// Horizontal divider dividing vertical panes; user drags vertically (up/down).
    case horizontal

    /// Vertical divider dividing horizontal panes; user drags horizontally (left/right).
    case vertical
}

/// A universal, interactive divider line providing smooth resize manipulation between adjacent views.
///
/// Designed to provide an ultra-clean visual line (typically 1pt) while providing a comfortable,
/// expanded mouse and touch target (e.g., 8–12pt) to eliminate missed grab attempts.
public struct Splitter: View {
    public let orientation: SplitterOrientation
    public let thickness: CGFloat
    public let hitArea: CGFloat
    public let baseColor: Color
    public let accentColor: Color
    public let onDrag: (@MainActor @Sendable (CGFloat) -> Void)?
    public let onReset: (@MainActor @Sendable () -> Void)?

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false
    @State private var lastDragTranslation: CGFloat = 0
    #if os(macOS)
    @State private var cursorPushed: Bool = false
    #endif

    /// Initializes a generic `Splitter`.
    ///
    /// - Parameters:
    ///   - orientation: Whether the divider is `.horizontal` (drags up/down) or `.vertical` (drags left/right).
    ///   - thickness: Visual thickness of the visible line (default is 1pt).
    ///   - hitArea: Extended interaction target area (default is 8pt).
    ///   - baseColor: Passive color of the divider (default is subtle white/border opacity).
    ///   - accentColor: Active illumination color when hovered or dragged (default is accent color).
    ///   - onDrag: Closure called with the incremental delta in points during dragging.
    ///   - onReset: Optional closure invoked when the splitter is double-clicked.
    public init(
        orientation: SplitterOrientation = .horizontal,
        thickness: CGFloat = 1,
        hitArea: CGFloat = 8,
        baseColor: Color = Color.primary.opacity(0.12),
        accentColor: Color = Color.accentColor,
        onDrag: (@MainActor @Sendable (CGFloat) -> Void)? = nil,
        onReset: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.orientation = orientation
        self.thickness = thickness
        self.hitArea = max(hitArea, thickness)
        self.baseColor = baseColor
        self.accentColor = accentColor
        self.onDrag = onDrag
        self.onReset = onReset
    }

    public var body: some View {
        ZStack {
            // Invisible extended hit area
            Color.clear
                .contentShape(Rectangle())

            // Visible line
            Rectangle()
                .fill(isHovered || isDragging ? accentColor : baseColor)
                .frame(
                    width: orientation == .vertical ? thickness : nil,
                    height: orientation == .horizontal ? thickness : nil
                )
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
        }
        .frame(
            width: orientation == .vertical ? hitArea : nil,
            height: orientation == .horizontal ? hitArea : nil
        )
        .onHover { hovering in
            guard !isDragging else { return }
            isHovered = hovering
            #if os(macOS)
            if hovering {
                if !cursorPushed {
                    pushCursor()
                    cursorPushed = true
                }
            } else {
                if cursorPushed {
                    popCursor()
                    cursorPushed = false
                }
            }
            #endif
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onReset?()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        lastDragTranslation = 0
                        #if os(macOS)
                        if !cursorPushed {
                            pushCursor()
                            cursorPushed = true
                        }
                        #endif
                    }

                    let currentTranslation: CGFloat
                    switch orientation {
                    case .horizontal:
                        currentTranslation = value.translation.height
                    case .vertical:
                        currentTranslation = value.translation.width
                    }

                    let delta = currentTranslation - lastDragTranslation
                    lastDragTranslation = currentTranslation
                    onDrag?(delta)
                }
                .onEnded { _ in
                    isDragging = false
                    lastDragTranslation = 0
                    #if os(macOS)
                    if !isHovered && cursorPushed {
                        popCursor()
                        cursorPushed = false
                    }
                    #endif
                }
        )
    }

    #if os(macOS)
    private func pushCursor() {
        switch orientation {
        case .horizontal:
            NSCursor.resizeUpDown.push()
        case .vertical:
            NSCursor.resizeLeftRight.push()
        }
    }

    private func popCursor() {
        NSCursor.pop()
    }
    #endif
}


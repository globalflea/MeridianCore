// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0 with Runtime Library Exception

import SwiftUI

/// Abstract protocol governing timeline playback and scrubbing states.
@MainActor
public protocol TimelinePlaybackControlling: AnyObject {
    var currentTime: Double { get set }
    var totalDuration: Double { get }
    var isPlaying: Bool { get }
    var speedMultiplier: Double { get set }
    var keyframeCoordinates: [Double] { get }

    func play()
    func pause()
    func togglePlayPause()
    func stepBackward()
    func stepForward()
    func seek(to time: Double)
}

/// Standalone observable model conforming to `TimelinePlaybackControlling`.
@Observable
@MainActor
public final class TimelineScrubberModel: TimelinePlaybackControlling {
    public var currentTime: Double
    public var totalDuration: Double
    public var isPlaying: Bool
    public var speedMultiplier: Double
    public var keyframeCoordinates: [Double]

    public var onSeek: ((Double) -> Void)?
    public var onStep: ((Int) -> Void)?
    public var onPlayPause: ((Bool) -> Void)?

    public init(
        currentTime: Double = 0.0,
        totalDuration: Double = 100.0,
        isPlaying: Bool = false,
        speedMultiplier: Double = 1.0,
        keyframeCoordinates: [Double] = []
    ) {
        self.currentTime = currentTime
        self.totalDuration = max(0.001, totalDuration)
        self.isPlaying = isPlaying
        self.speedMultiplier = speedMultiplier
        self.keyframeCoordinates = keyframeCoordinates
    }

    public func play() {
        isPlaying = true
        onPlayPause?(true)
    }

    public func pause() {
        isPlaying = false
        onPlayPause?(false)
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    public func stepBackward() {
        currentTime = max(0, currentTime - 1.0)
        onStep?(-1)
        onSeek?(currentTime)
    }

    public func stepForward() {
        currentTime = min(totalDuration, currentTime + 1.0)
        onStep?(1)
        onSeek?(currentTime)
    }

    public func seek(to time: Double) {
        currentTime = min(max(0, time), totalDuration)
        onSeek?(currentTime)
    }
}

/// Formats a time in seconds to HH:MM:SS.mmm.
public func formatTimelineSeconds(_ seconds: Double) -> String {
    let totalMs = Int(seconds * 1000)
    let ms = totalMs % 1000
    let s = (totalMs / 1000) % 60
    let m = (totalMs / 60000) % 60
    let h = totalMs / 3600000
    return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
}

/// An interactive, glassmorphic timeline scrubber bar adhering to Apple Human Interface Guidelines (HIG).
public struct TimelineScrubberBar<Controller: TimelinePlaybackControlling>: View {
    public let controller: Controller
    public let formatTimestamp: @Sendable (Double) -> String
    @State private var isDragging: Bool = false
    @State private var dragPosition: Double = 0.0

    public static var availableSpeeds: [Double] {
        [0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 100.0]
    }

    public init(
        controller: Controller,
        formatTimestamp: @escaping @Sendable (Double) -> String = formatTimelineSeconds
    ) {
        self.controller = controller
        self.formatTimestamp = formatTimestamp
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Playback controls
            HStack(spacing: 6) {
                Button {
                    controller.stepBackward()
                } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Step Backward (Previous Frame)")

                Button {
                    controller.togglePlayPause()
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.accentColor.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .help(controller.isPlaying ? "Pause Simulation" : "Play Simulation")

                Button {
                    controller.stepForward()
                } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Step Forward (Next Frame)")
            }

            // Interactive scrubber track with keyframe pips
            GeometryReader { geo in
                let progress = normalizedProgress
                let width = geo.size.width
                let height = geo.size.height

                ZStack(alignment: .leading) {
                    // Background rail
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Active progress fill
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, min(width, width * CGFloat(progress))), height: 6)

                    // Keyframe markers
                    ForEach(controller.keyframeCoordinates, id: \.self) { kf in
                        let kfProgress = min(1.0, max(0.0, kf / controller.totalDuration))
                        Circle()
                            .fill(Color.yellow.opacity(0.85))
                            .frame(width: 5, height: 5)
                            .position(x: width * CGFloat(kfProgress), y: height / 2)
                    }

                    // Scrubber handle / thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        .position(x: width * CGFloat(progress), y: height / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let ratio = min(1.0, max(0.0, Double(value.location.x / width)))
                            let targetTime = ratio * controller.totalDuration
                            dragPosition = targetTime
                            controller.seek(to: targetTime)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 24)

            // Current Time / Duration readout
            Text("\(formatTimestamp(displayTime)) / \(formatTimestamp(controller.totalDuration))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 120, alignment: .trailing)

            // Speed selection menu
            Menu {
                ForEach(Self.availableSpeeds, id: \.self) { speed in
                    Button {
                        controller.speedMultiplier = speed
                    } label: {
                        HStack {
                            Text(speedLabel(for: speed))
                            if controller.speedMultiplier == speed {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(speedLabel(for: controller.speedMultiplier))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            MeridianGlassCard(cornerStyle: .continuous(14), material: .ultraThinMaterial) {
                Color.clear
            }
        )
    }

    private var displayTime: Double {
        isDragging ? dragPosition : controller.currentTime
    }

    private var normalizedProgress: Double {
        guard controller.totalDuration > 0 else { return 0.0 }
        let current = isDragging ? dragPosition : controller.currentTime
        return min(1.0, max(0.0, current / controller.totalDuration))
    }

    private func speedLabel(for speed: Double) -> String {
        if speed >= 100.0 { return "AFAP" }
        if speed == floor(speed) {
            return "\(Int(speed))×"
        }
        return String(format: "%.1f×", speed)
    }

    public nonisolated static func defaultFormatTime(_ seconds: Double) -> String {
        formatTimelineSeconds(seconds)
    }
}

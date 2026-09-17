// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0 with Runtime Library Exception

import Testing
import Foundation
@testable import MeridianUI

@Suite("TimelineScrubberBar Tests")
struct TimelineScrubberBarTests {

    @Test("TimelineScrubberModel playback state transitions and callbacks")
    @MainActor
    func testModelPlaybackTransitions() {
        let model = TimelineScrubberModel(totalDuration: 60.0)

        #expect(!model.isPlaying)
        #expect(model.currentTime == 0.0)
        #expect(model.totalDuration == 60.0)

        var playPauseEvent: Bool?
        model.onPlayPause = { playPauseEvent = $0 }

        model.play()
        #expect(model.isPlaying)
        #expect(playPauseEvent == true)

        model.pause()
        #expect(!model.isPlaying)
        #expect(playPauseEvent == false)

        model.togglePlayPause()
        #expect(model.isPlaying)
    }

    @Test("TimelineScrubberModel step and seek bounds clamping")
    @MainActor
    func testModelSteppingAndSeeking() {
        let model = TimelineScrubberModel(
            currentTime: 5.0,
            totalDuration: 10.0,
            keyframeCoordinates: [0.0, 2.5, 5.0, 7.5, 10.0]
        )

        model.stepForward()
        #expect(model.currentTime == 6.0)

        model.stepBackward()
        #expect(model.currentTime == 5.0)

        // Seek forward beyond duration clamps to totalDuration
        model.seek(to: 99.0)
        #expect(model.currentTime == 10.0)

        // Seek backward below zero clamps to 0.0
        model.seek(to: -5.0)
        #expect(model.currentTime == 0.0)

        #expect(model.keyframeCoordinates.count == 5)
    }

    @Test("TimelineScrubberBar time formatting helper")
    func testTimeFormatting() {
        let t1 = TimelineScrubberBar<TimelineScrubberModel>.defaultFormatTime(0.0)
        #expect(t1 == "00:00:00.000")

        let t2 = TimelineScrubberBar<TimelineScrubberModel>.defaultFormatTime(65.123)
        #expect(t2 == "00:01:05.123")

        let t3 = TimelineScrubberBar<TimelineScrubberModel>.defaultFormatTime(3661.5)
        #expect(t3 == "01:01:01.500")
    }
}

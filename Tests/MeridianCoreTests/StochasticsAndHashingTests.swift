// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0 with Runtime Library Exception

import Foundation
import Testing
@testable import MeridianCore

@Suite("Stochastics & Data Integrity Hashing Tests")
struct StochasticsAndHashingTests {
    @Test("Xoshiro256** deterministic reproducibility across runs")
    func xoshiroReproducibility() {
        var rng1 = Xoshiro256StarStar(seed: 12345)
        var rng2 = Xoshiro256StarStar(seed: 12345)

        for _ in 0..<100 {
            #expect(rng1.nextUInt64() == rng2.nextUInt64())
            #expect(rng1.nextDouble() == rng2.nextDouble())
        }
    }

    @Test("Uniform double bounds [0.0, 1.0) and range scaling")
    func uniformDoubleBounds() {
        var rng = Xoshiro256StarStar(seed: 999)
        for _ in 0..<1000 {
            let val = rng.nextDouble()
            #expect(val >= 0.0)
            #expect(val < 1.0)

            let scaled = rng.nextDouble(in: 10.0..<20.0)
            #expect(scaled >= 10.0)
            #expect(scaled < 20.0)
        }
    }

    @Test("Exponential distribution samples are positive and mean converges")
    func exponentialDistribution() {
        var rng = Xoshiro256StarStar(seed: 42)
        let lambda = 2.0
        let trials = 10000
        var sum = 0.0

        for _ in 0..<trials {
            let sample = Distribution.exponential(lambda: lambda, using: &rng)
            #expect(sample > 0.0)
            sum += sample
        }

        let mean = sum / Double(trials)
        let expectedMean = 1.0 / lambda
        #expect(abs(mean - expectedMean) < 0.05)
    }

    @Test("Normal distribution mean and standard deviation convergence")
    func normalDistribution() {
        var rng = Xoshiro256StarStar(seed: 777)
        let targetMean = 10.0
        let targetStdDev = 2.0
        let trials = 10000
        var sum = 0.0
        var sumSq = 0.0

        for _ in 0..<trials {
            let sample = Distribution.normal(mean: targetMean, stdDev: targetStdDev, using: &rng)
            sum += sample
            sumSq += sample * sample
        }

        let empiricalMean = sum / Double(trials)
        let empiricalVariance = (sumSq / Double(trials)) - (empiricalMean * empiricalMean)
        let empiricalStdDev = sqrt(empiricalVariance)

        #expect(abs(empiricalMean - targetMean) < 0.1)
        #expect(abs(empiricalStdDev - targetStdDev) < 0.1)
    }

    @Test("Poisson distribution non-negativity and mean convergence")
    func poissonDistribution() {
        var rng = Xoshiro256StarStar(seed: 888)
        let lambda = 5.0
        let trials = 5000
        var sum = 0

        for _ in 0..<trials {
            let sample = Distribution.poisson(lambda: lambda, using: &rng)
            #expect(sample >= 0)
            sum += sample
        }

        let empiricalMean = Double(sum) / Double(trials)
        #expect(abs(empiricalMean - lambda) < 0.15)
    }

    @Test("Adler-32 checksum matches RFC 1950 reference vector")
    func adler32ReferenceVector() {
        // RFC 1950 test vector: "Wikipedia" -> 0x11E60398
        let checksum = Adler32.checksum(string: "Wikipedia")
        #expect(checksum == 0x11E60398)

        // Empty data -> 0x00000001
        let emptyChecksum = Adler32.checksum(string: "")
        #expect(emptyChecksum == 1)

        // Data and String consistency
        let data = "MeridianUmbrella".data(using: .utf8)!
        #expect(Adler32.checksum(data: data) == Adler32.checksum(string: "MeridianUmbrella"))
    }
}

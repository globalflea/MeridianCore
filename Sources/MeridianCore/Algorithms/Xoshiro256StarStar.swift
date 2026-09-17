// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0 with Runtime Library Exception

import Foundation

/// A high-performance, deterministic pseudo-random number generator (PRNG) implementing `Xoshiro256**`.
///
/// Based on Blackman & Vigna (2021), *Scrambled Linear Pseudorandom Number Generators*,
/// ACM Transactions on Mathematical Software, 47(4).
///
/// Provides a period of $2^{256} - 1$, passes all BigCrush and PractRand statistical batteries,
/// and guarantees 100% bit-accurate cross-platform determinism across macOS, Linux, and CI runners.
public struct Xoshiro256StarStar: Sendable {
    private var s0: UInt64
    private var s1: UInt64
    private var s2: UInt64
    private var s3: UInt64

    /// Initializes the generator with a 64-bit master seed, expanding state via SplitMix64.
    /// - Parameter seed: The 64-bit seed value.
    public init(seed: UInt64) {
        var smState = seed
        self.s0 = Self.splitmix64(&smState)
        self.s1 = Self.splitmix64(&smState)
        self.s2 = Self.splitmix64(&smState)
        self.s3 = Self.splitmix64(&smState)
        if s0 == 0 && s1 == 0 && s2 == 0 && s3 == 0 {
            self.s0 = 1
        }
    }

    /// Initializes the generator with explicit 256-bit state words.
    public init(s0: UInt64, s1: UInt64, s2: UInt64, s3: UInt64) {
        precondition(s0 != 0 || s1 != 0 || s2 != 0 || s3 != 0, "All state words cannot be zero")
        self.s0 = s0
        self.s1 = s1
        self.s2 = s2
        self.s3 = s3
    }

    /// Generates the next pseudorandom 64-bit unsigned integer.
    public mutating func nextUInt64() -> UInt64 {
        let result = Self.rotl(s1 &* 5, 7) &* 9
        let t = s1 << 17

        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = Self.rotl(s3, 45)

        return result
    }

    /// Generates a floating-point number uniformly distributed in the half-open interval $[0.0, 1.0)$.
    /// Uses 53 bits of randomness for maximum IEEE 754 double precision.
    public mutating func nextDouble() -> Double {
        let random53 = nextUInt64() >> 11
        return Double(random53) * (1.0 / 9007199254740992.0) // 1.0 / 2^53
    }

    /// Generates a double uniformly distributed in the interval $[min, max)$.
    public mutating func nextDouble(in range: Range<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    // MARK: - Helper Bit Rotations

    @inline(__always)
    private static func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        (x << k) | (x >> (64 - k))
    }

    private static func splitmix64(_ state: inout UInt64) -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

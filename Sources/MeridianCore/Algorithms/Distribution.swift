// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0 with Runtime Library Exception

import Foundation

/// Standard statistical probability distributions for stochastic modeling, Monte Carlo simulation, and financial mathematics.
public enum Distribution {

    /// Samples from an Exponential distribution with rate parameter $\lambda > 0$.
    ///
    /// The probability density function is $f(x) = \lambda e^{-\lambda x}$ for $x \ge 0$.
    /// Uses inverse transform sampling: $X = -\frac{\ln(1 - U)}{\lambda}$.
    /// Commonly used to model inter-arrival times, order flow, and service durations.
    ///
    /// - Parameters:
    ///   - lambda: The rate parameter ($\lambda > 0$).
    ///   - prng: The pseudo-random number generator.
    /// - Returns: A sampled positive floating-point value.
    public static func exponential(lambda: Double, using prng: inout Xoshiro256StarStar) -> Double {
        precondition(lambda > 0.0, "Exponential lambda must be strictly positive: \(lambda)")
        let u = max(Double.leastNonzeroMagnitude, prng.nextDouble())
        return -log(1.0 - u) / lambda
    }

    /// Samples from a Normal (Gaussian) distribution with mean $\mu$ and standard deviation $\sigma \ge 0$.
    ///
    /// Uses the Box-Muller transform:
    /// $$Z = \sqrt{-2 \ln U_1} \cos(2\pi U_2), \quad X = \mu + \sigma Z$$
    ///
    /// - Parameters:
    ///   - mean: Mean value ($\mu$).
    ///   - stdDev: Standard deviation ($\sigma \ge 0$).
    ///   - prng: The pseudo-random number generator.
    /// - Returns: A sampled normal random variate.
    public static func normal(mean: Double = 0.0, stdDev: Double = 1.0, using prng: inout Xoshiro256StarStar) -> Double {
        precondition(stdDev >= 0.0, "Standard deviation cannot be negative: \(stdDev)")
        guard stdDev > 0.0 else { return mean }

        let u1 = max(Double.leastNonzeroMagnitude, prng.nextDouble())
        let u2 = prng.nextDouble()

        let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * Double.pi * u2)
        return mean + stdDev * z0
    }

    /// Samples an integer from a Poisson distribution with parameter $\lambda > 0$.
    ///
    /// Represents the number of discrete events occurring in a fixed interval.
    /// For $\lambda < 30$, Knuth's direct multiplication algorithm is employed.
    /// For $\lambda \ge 30$, a Gaussian approximation with continuity correction is used.
    ///
    /// - Parameters:
    ///   - lambda: Expected event count ($\lambda > 0$).
    ///   - prng: The pseudo-random number generator.
    /// - Returns: Sampled non-negative event count.
    public static func poisson(lambda: Double, using prng: inout Xoshiro256StarStar) -> Int {
        precondition(lambda > 0.0, "Poisson lambda must be strictly positive: \(lambda)")

        if lambda < 30.0 {
            let l = exp(-lambda)
            var k = 0
            var p = 1.0
            repeat {
                k += 1
                p *= max(Double.leastNonzeroMagnitude, prng.nextDouble())
            } while p > l
            return k - 1
        } else {
            // Gaussian approximation: Normal(mean = lambda, stdDev = sqrt(lambda))
            let sample = normal(mean: lambda, stdDev: sqrt(lambda), using: &prng)
            return max(0, Int(round(sample)))
        }
    }

    /// Samples a uniformly distributed integer in a closed range $[min, max]$.
    public static func uniformInt(in range: ClosedRange<Int>, using prng: inout Xoshiro256StarStar) -> Int {
        let count = UInt64(range.count)
        guard count > 1 else { return range.lowerBound }
        let offset = prng.nextUInt64() % count
        return range.lowerBound + Int(offset)
    }
}

// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0 with Runtime Library Exception

import Foundation

/// Fast Adler-32 checksum calculator (RFC 1950) for telemetry, packet headers, and data integrity verification.
///
/// Computes a 32-bit checksum composed of two 16-bit sums modulo 65521 ($s_1$ and $s_2$):
/// $$s_1 = 1 + \sum_{i=0}^{n-1} D_i \pmod{65521}, \quad s_2 = \sum_{i=0}^{n-1} (n - i) D_i \pmod{65521}$$
/// Offering significantly lower computational overhead than cryptographic hashes while catching bit flips and bursts.
public enum Adler32: Sendable {
    private static let mod: UInt32 = 65521

    /// Computes the Adler-32 checksum of a byte sequence.
    public static func checksum<T: Sequence>(bytes: T) -> UInt32 where T.Element == UInt8 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in bytes {
            a = (a + UInt32(byte)) % mod
            b = (b + a) % mod
        }
        return (b << 16) | a
    }

    /// Computes the Adler-32 checksum of a UTF-8 string.
    public static func checksum(string: String) -> UInt32 {
        checksum(bytes: string.utf8)
    }

    /// Computes the Adler-32 checksum of a Foundation `Data` buffer.
    public static func checksum(data: Data) -> UInt32 {
        checksum(bytes: data)
    }
}

//
//  WALPersistenceSink.swift
//  MeridianCore
//
//  Created on 2026-09-17.
//

import Foundation

/// Swift 6 Sendable protocol defining a pluggable storage sink for Write-Ahead Log records.
///
/// Implementations of `WALPersistenceSink` receive batches of sequenced WAL records from a
/// coordinator (e.g. `WALBatchCoordinator`) and persist them into external data stores such as
/// PostgreSQL, TimescaleDB, ClickHouse, or object storage.
public protocol WALPersistenceSink: Sendable {
    /// Persists a batch of sequenced records atomically or idempotently.
    ///
    /// - Parameter records: Monotonically ordered array of log records to persist.
    /// - Throws: An error if the persistence tier rejects the batch or experiences an I/O failure.
    func persist(records: [WALRecord]) async throws

    /// Retrieves the highest sequence number successfully committed and acknowledged by the sink.
    ///
    /// - Returns: The latest committed sequence number, or `nil` if the sink contains no records.
    func lastCommittedSequenceNumber() async throws -> UInt64?
}

/// Structured record envelope augmenting a local `WALRecord` with distributed multi-node identifiers.
public struct DistributedWALRecord: Sendable, Equatable, Codable {
    /// Unique identifier of the originating node or worker instance.
    public let nodeId: String

    /// Monotonically increasing sequence number within the originating node.
    public let sequenceNumber: UInt64

    /// Timestamp when the record was persisted.
    public let timestamp: Date

    /// Timestamp in epoch milliseconds.
    public var timestampMillis: Int64 {
        Int64(timestamp.timeIntervalSince1970 * 1000)
    }

    /// Raw binary or serialized payload bytes.
    public let payload: Data

    /// Byte offset within the originating WAL file.
    public let offset: UInt64

    /// Total framed byte size.
    public let byteSize: Int

    /// Computed 64-bit CRC checksum of the payload.
    public let crc64: UInt64

    /// 4-byte magic identifier distinguishing the stream format.
    public let magic: UInt32

    /// Initializes a `DistributedWALRecord`.
    public init(
        nodeId: String,
        sequenceNumber: UInt64,
        timestamp: Date,
        payload: Data,
        offset: UInt64 = 0,
        byteSize: Int = 0,
        crc64: UInt64 = 0,
        magic: UInt32 = defaultWALBinaryMagic
    ) {
        self.nodeId = nodeId
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.payload = payload
        self.offset = offset
        self.byteSize = byteSize
        self.crc64 = crc64
        self.magic = magic
    }

    /// Converts a local `WALRecord` into a `DistributedWALRecord` with the specified `nodeId`.
    public init(record: WALRecord, nodeId: String) {
        self.init(
            nodeId: nodeId,
            sequenceNumber: record.sequenceNumber,
            timestamp: record.timestamp,
            payload: record.payload,
            offset: record.offset,
            byteSize: record.byteSize,
            crc64: record.crc64,
            magic: record.magic
        )
    }

    /// Converts this distributed record back to a local `WALRecord`.
    public var localRecord: WALRecord {
        WALRecord(
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            payload: payload,
            offset: offset,
            byteSize: byteSize,
            crc64: crc64,
            magic: magic
        )
    }
}

/// In-memory implementation of `WALPersistenceSink` for testing, benchmarking, and local simulations.
public actor InMemoryWALSink: WALPersistenceSink {
    /// Ordered journal of all records persisted across batches.
    public private(set) var persistedRecords: [WALRecord]

    /// Total count of `persist(records:)` invocations.
    public private(set) var persistCallCount: Int

    /// Highest sequence number committed to the sink.
    private var committedSeq: UInt64?

    /// Optional simulated error thrown on next `persist` call.
    public var simulatedError: (any Error)?

    /// Optional delay simulated before completing a persistence batch.
    public var simulatedLatencyNanos: UInt64?

    /// Initializes an empty `InMemoryWALSink`.
    public init(initialRecords: [WALRecord] = []) {
        self.persistedRecords = initialRecords
        self.persistCallCount = 0
        self.committedSeq = initialRecords.last?.sequenceNumber
        self.simulatedError = nil
        self.simulatedLatencyNanos = nil
    }

    public func persist(records: [WALRecord]) async throws {
        persistCallCount += 1

        if let latency = simulatedLatencyNanos {
            try? await Task.sleep(nanoseconds: latency)
        }

        if let error = simulatedError {
            throw error
        }

        guard !records.isEmpty else { return }
        persistedRecords.append(contentsOf: records)
        if let lastSeq = records.last?.sequenceNumber {
            committedSeq = max(committedSeq ?? 0, lastSeq)
        }
    }

    public func lastCommittedSequenceNumber() async throws -> UInt64? {
        committedSeq
    }

    /// Sets or clears a simulated error for resilience testing.
    public func setSimulatedError(_ error: (any Error)?) {
        self.simulatedError = error
    }

    /// Sets or clears simulated persistence latency in nanoseconds.
    public func setSimulatedLatencyNanos(_ nanos: UInt64?) {
        self.simulatedLatencyNanos = nanos
    }

    /// Clears all stored records and resets committed sequence tracking.
    public func clear() {
        persistedRecords.removeAll(keepingCapacity: true)
        persistCallCount = 0
        committedSeq = nil
        simulatedError = nil
        simulatedLatencyNanos = nil
    }
}

//
//  WALBatchCoordinator.swift
//  MeridianCore
//
//  Created on 2026-09-17.
//

import Foundation

/// Swift 6 actor-isolated batching coordinator for offloading Write-Ahead Log records.
///
/// Accumulates incoming `WALRecord`s into an in-memory buffer, automatically flushing batches
/// to an underlying `WALPersistenceSink` when either the buffer count exceeds `maxBatchSize`
/// or the periodic timer interval `flushInterval` elapses.
public actor WALBatchCoordinator {
    /// Underlying persistence sink receiving flushed record batches.
    public let sink: any WALPersistenceSink

    /// Maximum record count accumulated before triggering an immediate flush.
    public let maxBatchSize: Int

    /// Periodic time interval in seconds between automatic timer flushes.
    public let flushInterval: TimeInterval

    /// Maximum consecutive retry attempts when the sink throws a persistence error.
    public let maxRetryAttempts: Int

    /// Base retry delay in seconds for exponential backoff.
    public let baseRetryDelay: TimeInterval

    /// In-memory buffer of pending records awaiting persistence.
    private var buffer: [WALRecord]

    /// Periodic timer task driving interval-based flushing.
    private var timerTask: Task<Void, Never>?

    /// Optional background ingestion task reading from an attached `AsyncStream`.
    private var streamTask: Task<Void, Never>?

    /// Indicates whether the coordinator is active and accepting records.
    public private(set) var isOpen: Bool

    /// Highest sequence number committed and acknowledged by the sink.
    public private(set) var lastCommittedSeq: UInt64?

    /// Cumulative count of batches successfully flushed to the sink.
    public private(set) var totalBatchesFlushed: Int

    /// Cumulative count of individual records successfully flushed to the sink.
    public private(set) var totalRecordsFlushed: Int

    /// Current count of buffered records awaiting flush.
    public var pendingCount: Int {
        buffer.count
    }

    /// Initializes a `WALBatchCoordinator`.
    public init(
        sink: any WALPersistenceSink,
        maxBatchSize: Int = 500,
        flushInterval: TimeInterval = 0.1,
        maxRetryAttempts: Int = 3,
        baseRetryDelay: TimeInterval = 0.05
    ) {
        self.sink = sink
        self.maxBatchSize = max(1, maxBatchSize)
        self.flushInterval = max(0.005, flushInterval)
        self.maxRetryAttempts = max(0, maxRetryAttempts)
        self.baseRetryDelay = max(0.001, baseRetryDelay)
        self.buffer = []
        self.timerTask = nil
        self.streamTask = nil
        self.isOpen = true
        self.lastCommittedSeq = nil
        self.totalBatchesFlushed = 0
        self.totalRecordsFlushed = 0
    }

    deinit {
        timerTask?.cancel()
        streamTask?.cancel()
    }

    /// Starts the background periodic flush timer if not already active.
    public func start() {
        guard isOpen, timerTask == nil else { return }
        let intervalNanos = UInt64(flushInterval * 1_000_000_000)
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanos)
                guard let self = self else { break }
                try? await self.flushPendingIfAvailable()
            }
        }
    }

    /// Submits a single `WALRecord` to the buffer, triggering a flush if `maxBatchSize` is met.
    public func submit(record: WALRecord) async throws {
        guard isOpen else { throw WALError.writerClosed }
        start()
        buffer.append(record)
        if buffer.count >= maxBatchSize {
            try await flush()
        }
    }

    /// Submits a collection of records to the buffer, triggering a flush if `maxBatchSize` is met.
    public func submit(contentsOf records: [WALRecord]) async throws {
        guard isOpen else { throw WALError.writerClosed }
        guard !records.isEmpty else { return }
        start()
        buffer.append(contentsOf: records)
        if buffer.count >= maxBatchSize {
            try await flush()
        }
    }

    /// Attaches the coordinator to an `AsyncStream<WALRecord>`, ingesting records in the background.
    public func attach(to stream: AsyncStream<WALRecord>) {
        start()
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            for await record in stream {
                guard let self = self else { break }
                do {
                    try await self.submit(record: record)
                } catch {
                    break
                }
            }
        }
    }

    /// Flushes all currently buffered records to the configured `WALPersistenceSink`.
    public func flush() async throws {
        guard !buffer.isEmpty else { return }

        let batch = buffer
        buffer = []

        var attempt = 0
        var lastError: (any Error)?

        while attempt <= maxRetryAttempts {
            do {
                try await sink.persist(records: batch)
                totalBatchesFlushed += 1
                totalRecordsFlushed += batch.count
                if let last = batch.last {
                    self.lastCommittedSeq = max(self.lastCommittedSeq ?? 0, last.sequenceNumber)
                }
                return
            } catch {
                lastError = error
                attempt += 1
                if attempt <= maxRetryAttempts {
                    let delayNanos = UInt64(baseRetryDelay * pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNanos)
                }
            }
        }

        // On complete retry exhaustion, restore unpersisted batch to the front of buffer
        buffer.insert(contentsOf: batch, at: 0)
        if let err = lastError {
            throw err
        }
    }

    /// Retrieves the highest sequence number acknowledged by the underlying sink.
    public func lastCommittedSequenceNumber() async throws -> UInt64? {
        if let localSeq = lastCommittedSeq {
            return localSeq
        }
        let remoteSeq = try await sink.lastCommittedSequenceNumber()
        self.lastCommittedSeq = remoteSeq
        return remoteSeq
    }

    /// Closes the coordinator, flushing pending buffers and terminating background timer tasks.
    public func close() async throws {
        guard isOpen else { return }
        timerTask?.cancel()
        timerTask = nil
        streamTask?.cancel()
        streamTask = nil

        if !buffer.isEmpty {
            try await flush()
        }
        isOpen = false
    }

    // MARK: - Private Helpers

    private func flushPendingIfAvailable() async throws {
        guard isOpen, !buffer.isEmpty else { return }
        try await flush()
    }
}

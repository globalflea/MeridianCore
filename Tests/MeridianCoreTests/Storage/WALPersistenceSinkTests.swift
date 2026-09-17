//
//  WALPersistenceSinkTests.swift
//  MeridianCoreTests
//
//  Created on 2026-09-17.
//

import Foundation
import Testing
@testable import MeridianCore

@Suite("WAL Persistence Sink, Batch Coordinator & Postgres Schema Tests")
struct WALPersistenceSinkTests {
    private func makeSampleRecords(count: Int, startSeq: UInt64 = 1) -> [WALRecord] {
        (0..<count).map { i in
            let seq = startSeq + UInt64(i)
            let payload = Data("Transaction payload \(seq)".utf8)
            return WALRecord(
                sequenceNumber: seq,
                timestamp: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)),
                payload: payload,
                offset: UInt64(i * 64),
                byteSize: 64,
                crc64: CRC64.checksum(payload),
                magic: defaultWALBinaryMagic
            )
        }
    }

    @Test("InMemoryWALSink accurately persists batches and tracks sequence numbers")
    func testInMemorySinkBasic() async throws {
        let sink = InMemoryWALSink()
        #expect(await sink.persistedRecords.isEmpty)
        #expect(try await sink.lastCommittedSequenceNumber() == nil)

        // Test empty batch persistence
        try await sink.persist(records: [])
        #expect(await sink.persistedRecords.isEmpty)

        // Test simulated latency
        await sink.setSimulatedLatencyNanos(10_000)
        let records = makeSampleRecords(count: 5)
        try await sink.persist(records: records)

        #expect(await sink.persistedRecords.count == 5)
        #expect(await sink.persistCallCount == 2)
        #expect(try await sink.lastCommittedSequenceNumber() == 5)

        await sink.setSimulatedLatencyNanos(nil)
        let moreRecords = makeSampleRecords(count: 3, startSeq: 6)
        try await sink.persist(records: moreRecords)

        #expect(await sink.persistedRecords.count == 8)
        #expect(await sink.persistCallCount == 3)
        #expect(try await sink.lastCommittedSequenceNumber() == 8)

        await sink.clear()
        #expect(await sink.persistedRecords.isEmpty)
        #expect(try await sink.lastCommittedSequenceNumber() == nil)
    }

    @Test("DistributedWALRecord conversion and field fidelity")
    func testDistributedWALRecordConversion() {
        let local = makeSampleRecords(count: 1)[0]
        let distributed = DistributedWALRecord(record: local, nodeId: "worker-node-alpha")

        #expect(distributed.nodeId == "worker-node-alpha")
        #expect(distributed.sequenceNumber == local.sequenceNumber)
        #expect(distributed.timestamp == local.timestamp)
        #expect(distributed.timestampMillis == local.timestampMillis)
        #expect(distributed.payload == local.payload)
        #expect(distributed.offset == local.offset)
        #expect(distributed.byteSize == local.byteSize)
        #expect(distributed.crc64 == local.crc64)
        #expect(distributed.magic == local.magic)

        let roundTrip = distributed.localRecord
        #expect(roundTrip == local)
    }

    @Test("WALBatchCoordinator flushes immediately when maxBatchSize threshold is met")
    func testBatchCoordinatorThresholdFlush() async throws {
        let sink = InMemoryWALSink(initialRecords: makeSampleRecords(count: 2, startSeq: 1))
        let coordinator = WALBatchCoordinator(
            sink: sink,
            maxBatchSize: 5,
            flushInterval: 10.0 // Long timer to prevent timer interference
        )

        // Remote sequence lookup before any submissions
        #expect(try await coordinator.lastCommittedSequenceNumber() == 2)

        let records = makeSampleRecords(count: 4, startSeq: 3)
        try await coordinator.submit(contentsOf: records)

        #expect(await coordinator.pendingCount == 4)
        #expect(await sink.persistedRecords.count == 2)

        let fifth = makeSampleRecords(count: 1, startSeq: 7)[0]
        try await coordinator.submit(record: fifth)

        #expect(await coordinator.pendingCount == 0)
        #expect(await sink.persistedRecords.count == 7)
        #expect(await coordinator.totalBatchesFlushed == 1)
        #expect(try await coordinator.lastCommittedSequenceNumber() == 7)

        // Submit bulk array exceeding batch size directly
        let bulk = makeSampleRecords(count: 6, startSeq: 8)
        try await coordinator.submit(contentsOf: bulk)
        #expect(await coordinator.pendingCount == 0)
        #expect(await sink.persistedRecords.count == 13)

        // Empty submit is a no-op
        try await coordinator.submit(contentsOf: [])

        try await coordinator.close()
    }

    @Test("WALBatchCoordinator flushes automatically when flushInterval timer elapses")
    func testBatchCoordinatorTimerFlush() async throws {
        let sink = InMemoryWALSink()
        let coordinator = WALBatchCoordinator(
            sink: sink,
            maxBatchSize: 100, // High batch limit
            flushInterval: 0.05 // 50ms interval
        )

        let records = makeSampleRecords(count: 3)
        try await coordinator.submit(contentsOf: records)
        #expect(await coordinator.pendingCount == 3)

        // Wait for periodic timer to trigger
        try await Task.sleep(nanoseconds: 120_000_000) // 120ms

        #expect(await coordinator.pendingCount == 0)
        #expect(await sink.persistedRecords.count == 3)
        #expect(await coordinator.totalBatchesFlushed >= 1)

        try await coordinator.close()
    }

    @Test("WALBatchCoordinator ingests continuously from an attached AsyncStream")
    func testBatchCoordinatorAsyncStream() async throws {
        let sink = InMemoryWALSink()
        let coordinator = WALBatchCoordinator(sink: sink, maxBatchSize: 10, flushInterval: 0.05)

        var continuation: AsyncStream<WALRecord>.Continuation?
        let stream = AsyncStream<WALRecord> { cont in
            continuation = cont
        }

        await coordinator.attach(to: stream)

        let records = makeSampleRecords(count: 7)
        for r in records {
            continuation?.yield(r)
        }
        continuation?.finish()

        // Wait for background task to process stream elements and timer to flush
        try await Task.sleep(nanoseconds: 150_000_000)

        #expect(await sink.persistedRecords.count == 7)
        try await coordinator.close()
    }

    @Test("WALBatchCoordinator preserves buffer on sink error and succeeds on recovery")
    func testBatchCoordinatorErrorRecovery() async throws {
        let sink = InMemoryWALSink()
        await sink.clear()

        let coordinator = WALBatchCoordinator(
            sink: sink,
            maxBatchSize: 10,
            flushInterval: 10.0,
            maxRetryAttempts: 1,
            baseRetryDelay: 0.01
        )

        // Inject simulated failure on the sink
        await sink.setSimulatedError(WALError.ioError(reason: "Simulated network drop"))

        let records = makeSampleRecords(count: 3)
        try await coordinator.submit(contentsOf: records)
        #expect(await coordinator.pendingCount == 3)

        // Flush should fail due to simulated error, but restore pending records to buffer
        do {
            try await coordinator.flush()
            Issue.record("Expected flush to fail with simulated error")
        } catch {
            // Expected
        }
        #expect(await coordinator.pendingCount == 3)
        #expect(await sink.persistedRecords.isEmpty)

        // Clear error and retry flush: should succeed now
        await sink.setSimulatedError(nil)
        try await coordinator.flush()
        #expect(await sink.persistedRecords.count == 3)
        #expect(await coordinator.pendingCount == 0)

        try await coordinator.close()
    }

    @Test("WALBatchCoordinator drains buffer completely on close and rejects subsequent writes")
    func testBatchCoordinatorCloseDrainsBuffer() async throws {
        let sink = InMemoryWALSink()
        let coordinator = WALBatchCoordinator(sink: sink, maxBatchSize: 50, flushInterval: 10.0)

        let records = makeSampleRecords(count: 4)
        try await coordinator.submit(contentsOf: records)
        #expect(await coordinator.pendingCount == 4)

        try await coordinator.close()

        #expect(await coordinator.pendingCount == 0)
        #expect(await sink.persistedRecords.count == 4)
        #expect(await coordinator.isOpen == false)

        // Submitting to closed coordinator throws writerClosed
        do {
            try await coordinator.submit(record: records[0])
            Issue.record("Expected writerClosed error to be thrown")
        } catch WALError.writerClosed {
            // Expected
        }
    }

    @Test("PostgresSchemaContract generates valid DDL, index, insert, and copy SQL")
    func testPostgresSchemaContractSQLGeneration() {
        let ddlStandard = PostgresSchemaContract.createTableSQL(tableName: "test_wal", includeNodeId: false, asTimescaleHypertable: false)
        #expect(ddlStandard.contains("CREATE TABLE IF NOT EXISTS test_wal"))
        #expect(ddlStandard.contains("PRIMARY KEY (sequence_number)"))
        #expect(!ddlStandard.contains("node_id"))
        #expect(!ddlStandard.contains("create_hypertable"))

        let ddlTimescale = PostgresSchemaContract.createTableSQL(tableName: "cluster_wal", includeNodeId: true, asTimescaleHypertable: true)
        #expect(ddlTimescale.contains("node_id"))
        #expect(ddlTimescale.contains("PRIMARY KEY (node_id, sequence_number)"))
        #expect(ddlTimescale.contains("create_hypertable('cluster_wal'"))

        let indexes = PostgresSchemaContract.createIndexesSQL(tableName: "test_wal", includeNodeId: true)
        #expect(indexes.count == 3)
        #expect(indexes[0].contains("idx_test_wal_timestamp"))
        #expect(indexes[1].contains("idx_test_wal_ts_millis"))
        #expect(indexes[2].contains("idx_test_wal_node_ts"))

        let insertSQL = PostgresSchemaContract.insertStatementSQL(tableName: "test_wal", includeNodeId: true, onConflictDoNothing: true)
        #expect(insertSQL.contains("INSERT INTO test_wal (node_id, sequence_number"))
        #expect(insertSQL.contains("ON CONFLICT (node_id, sequence_number) DO NOTHING;"))

        let copySQL = PostgresSchemaContract.copyCommandSQL(tableName: "test_wal", includeNodeId: false)
        #expect(copySQL.contains("COPY test_wal (sequence_number"))
        #expect(copySQL.contains("FROM STDIN (FORMAT binary);"))

        let record = makeSampleRecords(count: 1)[0]
        let values = PostgresSchemaContract.columnValues(for: record, nodeId: "node-101")
        #expect(values["node_id"] as? String == "node-101")
        #expect(values["sequence_number"] as? Int64 == 1)
        #expect(values["timestamp_millis"] as? Int64 == record.timestampMillis)
    }
}

//
//  SQLiteWALPersistencePlaybackTests.swift
//  MeridianCoreTests
//
//  Created on 2026-09-17.
//

import Foundation
import Testing
@testable import MeridianCore

@Suite("SQLite WAL Persistence, End-to-End Pipeline & Playback Tests")
struct SQLiteWALPersistencePlaybackTests {
    private func makeRecords(count: Int, startSeq: UInt64 = 1, baseTime: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> [WALRecord] {
        (0..<count).map { i in
            let seq = startSeq + UInt64(i)
            let payload = Data("Transaction event payload #\(seq)".utf8)
            return WALRecord(
                sequenceNumber: seq,
                timestamp: baseTime.addingTimeInterval(Double(i)),
                payload: payload,
                offset: UInt64(i * 64),
                byteSize: 64,
                crc64: CRC64.checksum(payload),
                magic: defaultWALBinaryMagic
            )
        }
    }

    @Test("End-to-End Pipeline: WALWriter -> BatchCoordinator -> SQLiteWALSink -> Query")
    func testEndToEndWALToSQLitePipeline() async throws {
        let sink = SQLiteWALSink(databasePath: ":memory:", defaultNodeId: "node-primary")
        try await sink.open()

        let coordinator = WALBatchCoordinator(
            sink: sink,
            maxBatchSize: 5,
            flushInterval: 0.05
        )

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e_wal_\(UUID().uuidString).wal").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let writer = WALWriter(path: tempPath, syncPolicy: .always)
        try await writer.open()

        // Append 12 records to local WAL and forward to coordinator
        var generatedRecords: [WALRecord] = []
        for i in 1...12 {
            let payload = Data("State mutation record \(i)".utf8)
            let record = try await writer.append(payload: payload)
            generatedRecords.append(record)
            try await coordinator.submit(record: record)
        }

        try await coordinator.flush()
        try await writer.close()

        #expect(try await sink.count() == 12)
        #expect(try await sink.lastCommittedSequenceNumber() == 12)

        // Query back from SQLite and verify data integrity
        let queried = try await sink.queryRecords()
        #expect(queried.count == 12)

        for i in 0..<12 {
            #expect(queried[i].sequenceNumber == generatedRecords[i].sequenceNumber)
            #expect(queried[i].payload == generatedRecords[i].payload)
            #expect(queried[i].crc64 == generatedRecords[i].crc64)
            #expect(queried[i].crc64 == CRC64.checksum(queried[i].payload))
        }

        try await coordinator.close()
        try await sink.close()
    }

    @Test("Time-Range Querying and WALPlaybackController Replay from SQLite")
    func testTimeRangePlaybackFromSQLite() async throws {
        let sink = SQLiteWALSink(databasePath: ":memory:")
        try await sink.open()

        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
        let records = makeRecords(count: 20, baseTime: baseTime)
        try await sink.persist(records: records)

        // Query time window: seconds 5 through 14 (10 records expected)
        let startTime = baseTime.addingTimeInterval(5.0)
        let endTime = baseTime.addingTimeInterval(14.0)

        let slice = try await sink.queryRecords(startTime: startTime, endTime: endTime)
        #expect(slice.count == 10)
        #expect(slice.first?.sequenceNumber == 6)
        #expect(slice.last?.sequenceNumber == 15)

        // Feed slice directly into WALPlaybackController
        let controller = WALPlaybackController(records: slice)
        let initialProgress = await controller.progress()
        #expect(initialProgress.total == 10)
        #expect(initialProgress.cursor == 0)

        // Step forward 4 records
        let stepped = await controller.step(count: 4)
        #expect(stepped.count == 4)
        #expect(stepped[0].sequenceNumber == 6)
        #expect(stepped[3].sequenceNumber == 9)

        let stepProgress = await controller.progress()
        #expect(stepProgress.cursor == 4)

        // Seek to sequence number 12
        await controller.seek(toSequence: 12)
        let seekProgress = await controller.progress()
        #expect(seekProgress.currentRecord?.sequenceNumber == 12)

        try await sink.close()
    }

    @Test("Multi-Node Distributed Replay with Interleaved Chronological Sorting")
    func testMultiNodeDistributedReplay() async throws {
        let sink = SQLiteWALSink(databasePath: ":memory:")
        try await sink.open()

        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
        var distributedBatch: [DistributedWALRecord] = []

        // 3 nodes producing events with interleaved timestamps
        let nodes = ["node-alpha", "node-beta", "node-gamma"]
        for i in 0..<15 {
            let node = nodes[i % 3]
            let nodeSeq = UInt64(i / 3 + 1) // 1...5 per node
            let payload = Data("Event from \(node) #\(nodeSeq)".utf8)
            let rec = DistributedWALRecord(
                nodeId: node,
                sequenceNumber: nodeSeq,
                timestamp: baseTime.addingTimeInterval(Double(i)),
                payload: payload,
                crc64: CRC64.checksum(payload)
            )
            distributedBatch.append(rec)
        }

        try await sink.persist(distributedRecords: distributedBatch)

        #expect(try await sink.count() == 15)
        #expect(try await sink.count(nodeId: "node-alpha") == 5)
        #expect(try await sink.count(nodeId: "node-beta") == 5)
        #expect(try await sink.count(nodeId: "node-gamma") == 5)

        #expect(try await sink.lastCommittedSequenceNumber(nodeId: "node-alpha") == 5)
        #expect(try await sink.lastCommittedSequenceNumber(nodeId: "node-beta") == 5)
        #expect(try await sink.lastCommittedSequenceNumber(nodeId: "node-gamma") == 5)

        // Query all records: verify global chronological interleaving
        let chronoSorted = try await sink.queryDistributedRecords()
        #expect(chronoSorted.count == 15)

        for i in 0..<14 {
            let tCurrent = chronoSorted[i].timestampMillis
            let tNext = chronoSorted[i + 1].timestampMillis
            #expect(tCurrent <= tNext)
        }

        // Query specific node with sequence filter
        let alphaFiltered = try await sink.queryDistributedRecords(nodeId: "node-alpha", fromSeq: 2, toSeq: 4)
        #expect(alphaFiltered.count == 3)
        #expect(alphaFiltered.map(\.sequenceNumber) == [2, 3, 4])

        try await sink.close()
    }

    @Test("Idempotency: Duplicate batches are safely ignored via INSERT OR IGNORE")
    func testIdempotentDuplicateBatchIngestion() async throws {
        let sink = SQLiteWALSink(databasePath: ":memory:")
        try await sink.open()

        let records = makeRecords(count: 8)
        try await sink.persist(records: records)
        #expect(try await sink.count() == 8)

        // Re-persist the exact same batch
        try await sink.persist(records: records)
        #expect(try await sink.count() == 8)

        let reQueried = try await sink.queryRecords()
        #expect(reQueried.count == 8)

        try await sink.close()
    }

    @Test("File-Based SQLite persistence survives connection re-open")
    func testFileBasedPersistenceReopen() async throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("persistent_wal_\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        // First session: create and persist
        let sink1 = SQLiteWALSink(databasePath: dbURL.path, defaultNodeId: "cluster-main")
        try await sink1.open()
        let records = makeRecords(count: 6)
        try await sink1.persist(records: records)
        #expect(try await sink1.count() == 6)
        try await sink1.close()

        // Second session: re-open from same file
        let sink2 = SQLiteWALSink(databasePath: dbURL.path, defaultNodeId: "cluster-main")
        try await sink2.open()
        #expect(try await sink2.count() == 6)
        #expect(try await sink2.lastCommittedSequenceNumber() == 6)

        let loaded = try await sink2.queryRecords()
        #expect(loaded.count == 6)
        #expect(loaded.last?.sequenceNumber == 6)
        try await sink2.close()
    }

    @Test("Edge cases: empty persist, re-open, nonexistent node queries, and closed error handling")
    func testEdgeCasesAndErrorHandling() async throws {
        let sink = SQLiteWALSink(databasePath: ":memory:")
        try await sink.open()
        // Calling open again when already open should be a no-op
        try await sink.open()

        // Empty batch persist
        try await sink.persist(distributedRecords: [])
        #expect(try await sink.count() == 0)
        #expect(try await sink.lastCommittedSequenceNumber(nodeId: "nonexistent") == nil)
        #expect(try await sink.count(nodeId: "nonexistent") == 0)

        // Add records and query with node and timestamp range
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
        let records = makeRecords(count: 5, baseTime: baseTime)
        try await sink.persist(records: records)

        let startTime = baseTime.addingTimeInterval(1.0)
        let endTime = baseTime.addingTimeInterval(3.0)
        let queriedRange = try await sink.queryDistributedRecords(
            nodeId: "default",
            startTime: startTime,
            endTime: endTime
        )
        #expect(queriedRange.count == 3)

        // Close sink
        try await sink.close()
        // Calling close again should be a no-op
        try await sink.close()

        // Calling methods when closed must throw WALError.writerClosed
        await #expect(throws: WALError.self) {
            try await sink.persist(records: records)
        }
        await #expect(throws: WALError.self) {
            _ = try await sink.queryRecords()
        }
        await #expect(throws: WALError.self) {
            _ = try await sink.count()
        }
        await #expect(throws: WALError.self) {
            _ = try await sink.lastCommittedSequenceNumber()
        }

        // Unclosed sink ARC deinit test
        do {
            let tempSink = SQLiteWALSink(databasePath: ":memory:")
            try await tempSink.open()
        }

        // Invalid database path open failure
        let invalidSink = SQLiteWALSink(databasePath: "/dev/null/forbidden/db.sqlite")
        await #expect(throws: WALError.self) {
            try await invalidSink.open()
        }

        // SQL execute success and syntax error handling
        let maintSink = SQLiteWALSink(databasePath: ":memory:")
        try await maintSink.open()
        try await maintSink.execute(sql: "PRAGMA schema_version;")
        await #expect(throws: WALError.self) {
            try await maintSink.execute(sql: "INVALID SQL SYNTAX;")
        }
        // Empty payload record verification
        let emptyRec = WALRecord(
            sequenceNumber: 99,
            timestamp: Date(),
            payload: Data(),
            offset: 0,
            byteSize: 0,
            crc64: 0,
            magic: defaultWALBinaryMagic
        )
        try await maintSink.persist(records: [emptyRec])
        let readBack = try await maintSink.queryRecords(fromSeq: 99, toSeq: 99)
        #expect(readBack.first?.payload == Data())
        try await maintSink.close()
    }
}

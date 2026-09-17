//
//  SQLiteWALSink.swift
//  MeridianCore
//
//  Created on 2026-09-17.
//

import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private final class SQLiteConnectionBox: @unchecked Sendable {
    var rawPointer: OpaquePointer?

    init(_ pointer: OpaquePointer?) {
        self.rawPointer = pointer
    }

    deinit {
        if let ptr = rawPointer {
            sqlite3_close_v2(ptr)
        }
    }
}

/// Swift 6 actor-isolated SQLite persistence sink for Write-Ahead Log records.
///
/// Implements `WALPersistenceSink` using Darwin's native `libsqlite3` with zero external dependencies.
/// Supports in-memory (`:memory:`) or file-based storage, high-throughput WAL mode pragmas,
/// transactional micro-batching, and SQL range queries for timeline playback.
public actor SQLiteWALSink: WALPersistenceSink {
    /// Filesystem path to the SQLite database, or `:memory:` for ephemeral storage.
    public let databasePath: String

    /// Default node identifier used when persisting standard `WALRecord` instances.
    public let defaultNodeId: String

    /// Thread-safe wrapper holding the underlying database pointer.
    private var connectionBox: SQLiteConnectionBox?

    /// Active SQLite connection pointer.
    private var db: OpaquePointer? {
        connectionBox?.rawPointer
    }

    /// Indicates whether the database connection is open and active.
    public private(set) var isOpen: Bool

    /// Initializes a `SQLiteWALSink`.
    public init(databasePath: String = ":memory:", defaultNodeId: String = "default") {
        self.databasePath = databasePath
        self.defaultNodeId = defaultNodeId
        self.connectionBox = nil
        self.isOpen = false
    }

    deinit {
        // Automatic cleanup via SQLiteConnectionBox ARC deinit
    }

    /// Opens the SQLite database connection, enables WAL mode, and applies the schema.
    public func open() throws {
        guard !isOpen else { return }

        var rawDb: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(databasePath, &rawDb, flags, nil) == SQLITE_OK else {
            let msg = rawDb.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            if let ptr = rawDb { sqlite3_close_v2(ptr) }
            throw WALError.ioError(reason: "Failed to open SQLite database at \(databasePath): \(msg)")
        }

        self.connectionBox = SQLiteConnectionBox(rawDb)

        // Pragmas for high-throughput append and memory optimization
        try execute(sql: "PRAGMA journal_mode = WAL;")
        try execute(sql: "PRAGMA synchronous = NORMAL;")
        try execute(sql: "PRAGMA temp_store = MEMORY;")

        try createSchema()
        self.isOpen = true
    }

    /// Persists a batch of local `WALRecord`s under `defaultNodeId`.
    public func persist(records: [WALRecord]) async throws {
        let distributed = records.map { DistributedWALRecord(record: $0, nodeId: defaultNodeId) }
        try await persist(distributedRecords: distributed)
    }

    /// Persists a batch of `DistributedWALRecord`s atomically with `INSERT OR IGNORE` idempotency.
    public func persist(distributedRecords records: [DistributedWALRecord]) async throws {
        guard isOpen, let db = db else { throw WALError.writerClosed }
        guard !records.isEmpty else { return }

        try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        var insertStmt: OpaquePointer?
        let sql = "INSERT OR IGNORE INTO wal_records (node_id, sequence_number, timestamp_millis, offset_bytes, byte_size, crc64, magic, payload) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8);"

        guard sqlite3_prepare_v2(db, sql, -1, &insertStmt, nil) == SQLITE_OK else {
            try? execute(sql: "ROLLBACK;")
            throw WALError.ioError(reason: "Failed to prepare insert statement: \(errorMessage)")
        }
        defer { sqlite3_finalize(insertStmt) }

        do {
            for record in records {
                sqlite3_reset(insertStmt)
                sqlite3_clear_bindings(insertStmt)

                sqlite3_bind_text(insertStmt, 1, (record.nodeId as NSString).utf8String, -1, sqliteTransient)
                sqlite3_bind_int64(insertStmt, 2, Int64(record.sequenceNumber))
                sqlite3_bind_int64(insertStmt, 3, record.timestampMillis)
                sqlite3_bind_int64(insertStmt, 4, Int64(record.offset))
                sqlite3_bind_int(insertStmt, 5, Int32(record.byteSize))
                sqlite3_bind_int64(insertStmt, 6, Int64(bitPattern: record.crc64))
                sqlite3_bind_int(insertStmt, 7, Int32(record.magic))

                _ = record.payload.withUnsafeBytes { raw in
                    sqlite3_bind_blob(insertStmt, 8, raw.baseAddress, Int32(record.payload.count), sqliteTransient)
                }

                guard sqlite3_step(insertStmt) == SQLITE_DONE else {
                    throw WALError.ioError(reason: "SQLite insert execution failed: \(errorMessage)")
                }
            }
            try execute(sql: "COMMIT;")
        } catch {
            try? execute(sql: "ROLLBACK;")
            throw error
        }
    }

    /// Retrieves the highest sequence number committed under `defaultNodeId`.
    public func lastCommittedSequenceNumber() async throws -> UInt64? {
        try await lastCommittedSequenceNumber(nodeId: defaultNodeId)
    }

    /// Retrieves the highest sequence number committed under the specified `nodeId`.
    public func lastCommittedSequenceNumber(nodeId: String) async throws -> UInt64? {
        guard isOpen, let db = db else { throw WALError.writerClosed }
        var stmt: OpaquePointer?
        let sql = "SELECT MAX(sequence_number) FROM wal_records WHERE node_id = ?1;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (nodeId as NSString).utf8String, -1, sqliteTransient)
        if sqlite3_step(stmt) == SQLITE_ROW, sqlite3_column_type(stmt, 0) != SQLITE_NULL {
            return UInt64(sqlite3_column_int64(stmt, 0))
        }
        return nil
    }

    /// Queries records for timeline playback matching optional node, sequence, and time filters.
    public func queryRecords(
        nodeId: String? = nil,
        fromSeq: UInt64? = nil,
        toSeq: UInt64? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) async throws -> [WALRecord] {
        let distributed = try await queryDistributedRecords(
            nodeId: nodeId,
            fromSeq: fromSeq,
            toSeq: toSeq,
            startTime: startTime,
            endTime: endTime
        )
        return distributed.map(\.localRecord)
    }

    /// Queries `DistributedWALRecord`s matching optional filters, ordered chronologically.
    public func queryDistributedRecords(
        nodeId: String? = nil,
        fromSeq: UInt64? = nil,
        toSeq: UInt64? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) async throws -> [DistributedWALRecord] {
        guard isOpen, let db = db else { throw WALError.writerClosed }

        var conditions: [String] = []
        if nodeId != nil { conditions.append("node_id = ?") }
        if fromSeq != nil { conditions.append("sequence_number >= ?") }
        if toSeq != nil { conditions.append("sequence_number <= ?") }
        if startTime != nil { conditions.append("timestamp_millis >= ?") }
        if endTime != nil { conditions.append("timestamp_millis <= ?") }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = """
        SELECT node_id, sequence_number, timestamp_millis, offset_bytes, byte_size, crc64, magic, payload 
        FROM wal_records \(whereClause) 
        ORDER BY timestamp_millis ASC, sequence_number ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw WALError.ioError(reason: "Failed to prepare query: \(errorMessage)")
        }
        defer { sqlite3_finalize(stmt) }

        var bindIndex: Int32 = 1
        if let nid = nodeId { sqlite3_bind_text(stmt, bindIndex, (nid as NSString).utf8String, -1, sqliteTransient); bindIndex += 1 }
        if let fs = fromSeq { sqlite3_bind_int64(stmt, bindIndex, Int64(fs)); bindIndex += 1 }
        if let ts = toSeq { sqlite3_bind_int64(stmt, bindIndex, Int64(ts)); bindIndex += 1 }
        if let st = startTime { sqlite3_bind_int64(stmt, bindIndex, Int64(st.timeIntervalSince1970 * 1000)); bindIndex += 1 }
        if let et = endTime { sqlite3_bind_int64(stmt, bindIndex, Int64(et.timeIntervalSince1970 * 1000)); bindIndex += 1 }

        var results: [DistributedWALRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let nId = String(cString: sqlite3_column_text(stmt, 0))
            let seq = UInt64(sqlite3_column_int64(stmt, 1))
            let tsMillis = sqlite3_column_int64(stmt, 2)
            let offset = UInt64(sqlite3_column_int64(stmt, 3))
            let byteSize = Int(sqlite3_column_int(stmt, 4))
            let crc = UInt64(bitPattern: sqlite3_column_int64(stmt, 5))
            let magic = UInt32(sqlite3_column_int(stmt, 6))

            let blobBytes = sqlite3_column_blob(stmt, 7)
            let blobCount = Int(sqlite3_column_bytes(stmt, 7))
            let payload = blobBytes.map { Data(bytes: $0, count: blobCount) } ?? Data()

            let record = DistributedWALRecord(
                nodeId: nId,
                sequenceNumber: seq,
                timestamp: Date(timeIntervalSince1970: Double(tsMillis) / 1000.0),
                payload: payload,
                offset: offset,
                byteSize: byteSize,
                crc64: crc,
                magic: magic
            )
            results.append(record)
        }
        return results
    }

    /// Returns the total record count matching an optional `nodeId`.
    public func count(nodeId: String? = nil) async throws -> Int {
        guard isOpen, let db = db else { throw WALError.writerClosed }
        var stmt: OpaquePointer?
        let sql = nodeId != nil ? "SELECT COUNT(*) FROM wal_records WHERE node_id = ?1;" : "SELECT COUNT(*) FROM wal_records;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        if let nid = nodeId {
            sqlite3_bind_text(stmt, 1, (nid as NSString).utf8String, -1, sqliteTransient)
        }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    /// Closes the SQLite connection.
    public func close() throws {
        guard isOpen, let box = connectionBox else { return }
        if let ptr = box.rawPointer {
            sqlite3_close_v2(ptr)
            box.rawPointer = nil
        }
        self.connectionBox = nil
        self.isOpen = false
    }

    /// Executes an arbitrary SQL statement against the underlying SQLite database.
    ///
    /// Can be used for maintenance, checkpoints (`PRAGMA wal_checkpoint;`), or pragma configuration.
    public func execute(sql: String) throws {
        guard let db = db else { throw WALError.writerClosed }
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw WALError.ioError(reason: "SQLite exec failed: \(errorMessage)")
        }
    }

    // MARK: - Private Helpers

    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS wal_records (
            node_id               TEXT NOT NULL DEFAULT 'default',
            sequence_number       INTEGER NOT NULL,
            timestamp_millis      INTEGER NOT NULL,
            offset_bytes          INTEGER NOT NULL,
            byte_size             INTEGER NOT NULL,
            crc64                 INTEGER NOT NULL,
            magic                 INTEGER NOT NULL,
            payload               BLOB NOT NULL,
            PRIMARY KEY (node_id, sequence_number)
        );
        CREATE INDEX IF NOT EXISTS idx_wal_records_ts ON wal_records(timestamp_millis);
        CREATE INDEX IF NOT EXISTS idx_wal_records_node_ts ON wal_records(node_id, timestamp_millis);
        """
        try execute(sql: sql)
    }

    private var errorMessage: String {
        db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
    }
}

//
//  PostgresSchemaContract.swift
//  MeridianCore
//
//  Created on 2026-09-17.
//

import Foundation

/// PostgreSQL and TimescaleDB schema contract and SQL generation definitions for WAL persistence.
///
/// Provides canonical table schemas, index definitions, parameterized `INSERT` statements,
/// and `COPY FROM STDIN` streaming templates for persisting `WALRecord` and `DistributedWALRecord`
/// streams into PostgreSQL.
public struct PostgresSchemaContract: Sendable {
    /// Canonical table name used for WAL record persistence.
    public static let defaultTableName = "meridian_wal_records"

    /// Generates the canonical `CREATE TABLE` DDL statement.
    ///
    /// - Parameters:
    ///   - tableName: Name of the relation table (defaults to `meridian_wal_records`).
    ///   - includeNodeId: If `true`, adds a `node_id` column and uses composite PK `(node_id, sequence_number)`.
    ///   - asTimescaleHypertable: If `true`, appends TimescaleDB hypertable partitioning by `timestamp`.
    /// - Returns: Complete SQL DDL string.
    public static func createTableSQL(
        tableName: String = defaultTableName,
        includeNodeId: Bool = false,
        asTimescaleHypertable: Bool = false
    ) -> String {
        let pkClause = includeNodeId ? "PRIMARY KEY (node_id, sequence_number)" : "PRIMARY KEY (sequence_number)"
        let nodeIdColumn = includeNodeId ? "    node_id               VARCHAR(64) NOT NULL,\n" : ""

        var sql = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
        \(nodeIdColumn)    sequence_number       BIGINT NOT NULL,
            timestamp             TIMESTAMPTZ NOT NULL,
            timestamp_millis      BIGINT NOT NULL,
            offset_bytes          BIGINT NOT NULL,
            byte_size             INTEGER NOT NULL,
            crc64                 BIGINT NOT NULL,
            magic                 INTEGER NOT NULL,
            payload               BYTEA NOT NULL,
            \(pkClause)
        );
        """

        if asTimescaleHypertable {
            sql += "\nSELECT create_hypertable('\(tableName)', 'timestamp', if_not_exists => TRUE);"
        }

        return sql
    }

    /// Generates secondary index DDL statements for efficient time-series seeking and multi-node filtering.
    ///
    /// - Parameters:
    ///   - tableName: Name of the relation table.
    ///   - includeNodeId: If `true`, generates a composite index covering `(node_id, timestamp)`.
    /// - Returns: Array of `CREATE INDEX` SQL statements.
    public static func createIndexesSQL(
        tableName: String = defaultTableName,
        includeNodeId: Bool = false
    ) -> [String] {
        var statements: [String] = []

        let tsIndex = "CREATE INDEX IF NOT EXISTS idx_\(tableName)_timestamp ON \(tableName) (timestamp);"
        statements.append(tsIndex)

        let tsMillisIndex = "CREATE INDEX IF NOT EXISTS idx_\(tableName)_ts_millis ON \(tableName) (timestamp_millis);"
        statements.append(tsMillisIndex)

        if includeNodeId {
            let nodeTsIndex = "CREATE INDEX IF NOT EXISTS idx_\(tableName)_node_ts ON \(tableName) (node_id, timestamp);"
            statements.append(nodeTsIndex)
        }

        return statements
    }

    /// Generates a parameterized `INSERT INTO ... VALUES` SQL statement.
    ///
    /// - Parameters:
    ///   - tableName: Target table name.
    ///   - includeNodeId: If `true`, targets the `node_id` column.
    ///   - onConflictDoNothing: If `true`, appends `ON CONFLICT DO NOTHING` for idempotent ingestion.
    /// - Returns: Formatted SQL string with `$1, $2, ...` positional placeholders.
    public static func insertStatementSQL(
        tableName: String = defaultTableName,
        includeNodeId: Bool = false,
        onConflictDoNothing: Bool = true
    ) -> String {
        let columns: [String] = {
            var cols: [String] = []
            if includeNodeId { cols.append("node_id") }
            cols.append(contentsOf: [
                "sequence_number", "timestamp", "timestamp_millis",
                "offset_bytes", "byte_size", "crc64", "magic", "payload"
            ])
            return cols
        }()

        let placeholders = columns.indices.map { "$\($0 + 1)" }.joined(separator: ", ")
        let columnNames = columns.joined(separator: ", ")

        var sql = "INSERT INTO \(tableName) (\(columnNames)) VALUES (\(placeholders))"
        if onConflictDoNothing {
            let conflictTarget = includeNodeId ? "(node_id, sequence_number)" : "(sequence_number)"
            sql += " ON CONFLICT \(conflictTarget) DO NOTHING"
        }
        sql += ";"
        return sql
    }

    /// Generates a high-throughput PostgreSQL `COPY FROM STDIN` header command.
    ///
    /// - Parameters:
    ///   - tableName: Target table name.
    ///   - includeNodeId: Whether `node_id` is part of the stream.
    /// - Returns: The `COPY ... FROM STDIN (FORMAT binary)` command.
    public static func copyCommandSQL(
        tableName: String = defaultTableName,
        includeNodeId: Bool = false
    ) -> String {
        let columns = includeNodeId
            ? "node_id, sequence_number, timestamp, timestamp_millis, offset_bytes, byte_size, crc64, magic, payload"
            : "sequence_number, timestamp, timestamp_millis, offset_bytes, byte_size, crc64, magic, payload"
        return "COPY \(tableName) (\(columns)) FROM STDIN (FORMAT binary);"
    }

    /// Encodes a `WALRecord` into an ordered dictionary of column values for binding.
    ///
    /// - Parameters:
    ///   - record: Source `WALRecord`.
    ///   - nodeId: Optional node identifier.
    /// - Returns: Dictionary mapping column names to serializable values.
    public static func columnValues(for record: WALRecord, nodeId: String? = nil) -> [String: Sendable] {
        var values: [String: Sendable] = [
            "sequence_number": Int64(record.sequenceNumber),
            "timestamp": record.timestamp,
            "timestamp_millis": record.timestampMillis,
            "offset_bytes": Int64(record.offset),
            "byte_size": Int32(record.byteSize),
            "crc64": Int64(bitPattern: record.crc64),
            "magic": Int32(record.magic),
            "payload": record.payload
        ]
        if let nid = nodeId {
            values["node_id"] = nid
        }
        return values
    }
}

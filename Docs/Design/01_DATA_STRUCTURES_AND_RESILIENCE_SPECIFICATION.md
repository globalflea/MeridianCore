# MeridianCore: Core DataStructures, Storage & Resilience Specification
## Document 01: High-Throughput Collections, Crash-Resilient WAL Storage & Distributed Resilience

---

## 1. Executive Summary & Algorithmic Domain

High-velocity real-time processing, geospatial database kernels, and mission-critical distributed systems demand three structural pillars:
1. **Algorithmic Collections & Indexing**: Cache-conscious, thread-safe data structures that eliminate $O(N)$ contiguous memory shifting, linear scans, and mutual exclusion lock contention.
2. **Crash-Resilient Write-Ahead Log (WAL) Storage**: Generic append-only log engines featuring fixed-length 32-byte binary framing, 64-bit CRC-64 integrity verification, in-memory write buffering, segmented log rotation, automated retention pruning, torn EOF tail truncation recovery, and multi-node streaming replication.
3. **Distributed Fault-Tolerance & Resilience**: Decoupled, non-blocking resilience patterns that isolate business transactions from network partitions, remote process crashes, and at-least-once transport replay.

**`MeridianCore`** delivers these shared engineering foundations as a zero-dependency, pure Swift 6 multi-module system consumed by **`Tile38Swift`**, **`GruleSwift`**, **`EchartsSwift`**, and **`JointSwift`**.

---

## 2. Theoretical Foundations & Algorithmic Mechanics

### 2.1 Cache-Conscious B-Tree Indexing (`BTree<Key, Value>`)
A high-fanout, balanced search tree where every internal node contains multiple keys and child pointers, optimizing memory locality and minimizing CPU cache misses:

#### Invariants & Complexity
For a B-Tree of degree $M$ (where $M \ge 3$):
- **Node Capacity**: Every node (except root) contains at least $\lceil M / 2 \rceil - 1$ keys and at most $M - 1$ keys.
- **Child Pointers**: An internal node with $k$ keys contains exactly $k + 1$ children.
- **Tree Height**: For $N$ items, the maximum height is strictly bounded:
  $$h \le \left\lfloor \log_{\lceil M/2 \rceil} \left( \frac{N + 1}{2} \right) \right\rfloor$$
- **Computational Complexity**:
  - Search: $O(\log_M N)$
  - Insertion: $O(\log_M N)$ with node splitting upon overflow ($k = M$).
  - Deletion: $O(\log_M N)$ with key borrowing or sibling node merging upon underflow ($k < \lceil M/2 \rceil - 1$).
  - Range Scan: $O(\log_M N + K)$ to scan $K$ contiguous sequential entries in ascending or descending order.

```mermaid
graph TD
    Root["Root: [20 | 50]"]
    N1["Node 1: [5 | 10 | 15]"]
    N2["Node 2: [25 | 35 | 42]"]
    N3["Node 3: [60 | 75 | 90]"]

    Root -->|keys < 20| N1
    Root -->|20 <= keys < 50| N2
    Root -->|keys >= 50| N3
```

### 2.2 Constant-Time Power-of-Two Ring Buffer (`RingBuffer<Element>`)
A contiguous fixed-capacity circular buffer operating on bitwise power-of-two arithmetic without costly modulo division:
- **Bitmask Indexing**: When capacity $C = 2^k$, index wrapping is evaluated via bitwise AND:
  $$\text{slot} = \text{cursor} \ \& \ (C - 1)$$
  This avoids the expensive hardware integer division instruction (`div`/`idiv`, 10–25 CPU cycles) in favor of a single-cycle bitwise `and`.
- **FIFO Eviction Invariant**: When appending to a saturated buffer, the oldest element at the tail is atomically overwritten and returned, maintaining strict $O(1)$ constant time complexity with zero heap reallocations.

### 2.3 Monotonic Sliding Extremum Deque (`MonotonicDeque<Element>`)
Maintains a monotonic non-increasing or non-decreasing sequence of elements for $O(1)$ running minimum or maximum extraction over a sliding window:
- **Domination Pruning**: On inserting $(v, i)$ at index $i$, all tail elements $(v_{\text{tail}}, i_{\text{tail}})$ where $v \le v_{\text{tail}}$ (for running minimum) are pruned from the deque.
- **Amortized Analysis**: Each element enters and exits the deque at most once, yielding strictly $O(1)$ amortized time per operation over a sequence of $N$ insertions.

### 2.4 Mathematical CRC-64 ECMA-182 Checksum (`CRC64`)
Cyclic redundancy check utilizing polynomial long division over Galois field $\text{GF}(2)$:
- **Standard Generator Polynomial**:
  $$P(x) = x^{64} + x^{62} + x^{57} + x^{55} + x^{54} + x^{53} + x^{52} + x^{47} + x^{46} + x^{45} + x^{40} + x^{39} + x^{38} + x^{37} + x^{35} + x^{32} + x^{31} + x^{30} + x^{29} + x^{27} + x^{24} + x^{23} + x^{22} + x^{21} + x^{19} + x^{17} + x^{13} + x^{12} + x^{10} + x^9 + x^7 + x^4 + x + 1$$
  Expressed as normal hex integer: `0x42F0E1EBA9EA3693`.
- **Bitwise Table Optimization**: Precomputes a 256-entry lookup table representing 8-bit quotient reductions, processing arbitrary byte slices (`UnsafeRawBufferPointer`) at multiple gigabytes per second with zero memory allocation.

---

## 3. Crash-Resilient Write-Ahead Log (WAL) Architecture

### 3.1 32-Byte Binary Frame Specification

Every record written to disk is framed by a 32-byte header guaranteeing bit-level validation and structural boundaries:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Magic (0x57414C31)                      |  4 Bytes (ASCII 'WAL1')
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Payload Length (UInt32)                     |  4 Bytes (Big-Endian)
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                   Sequence Number (UInt64)                    |  8 Bytes (Monotonic ID)
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|               Timestamp Microseconds (UInt64)                 |  8 Bytes (Unix epoch)
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|               Payload CRC-64 ECMA-182 (UInt64)                |  8 Bytes Checksum
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Payload Data...                        |  Variable Length
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.2 Segmented Rotation, Sparse Index & Retention Mechanics
- **Automated Rotation**: When the active WAL segment exceeds `maxSegmentBytes` (e.g. 64 MB), `SegmentedWALWriter` flushes pending write buffers, invokes POSIX `fsync`, closes the segment, and atomically creates the next file named `wal_<sequence>.wal`.
- **Sparse Indexing (`WALIndex`)**: Maintains an in-memory B-Tree index mapping coarse sequence intervals and timestamps to exact byte offsets within segments, reducing random-access seeks from $O(N)$ linear scans to $O(\log S)$ binary searches.
- **Torn EOF Write Recovery**: If a process crash or power interruption occurs during a write, `WALReader` detects partial byte sequences or CRC mismatches at the tail of the last segment, isolates the invalid trailing slice, and automatically repairs the segment by truncating the file to the last verified record boundary.
- **Retention Policies (`WALRetentionPolicy`)**: Supports automated retention pruning:
  - `keepLastSegments(count: Int)`: Unlinks oldest closed segments once the file count exceeds the threshold.
  - `keepTotalBytes(limit: Int64)`: Enforces an aggregate storage budget, dropping oldest segments.
  - `timeWindow(seconds: TimeInterval)`: Purges segments where all records predate the cutoff.

---

### 3.3 Decoupled External Persistence Sinks & Centralized Distributed Playback

#### 1. Analytical Critique: The "WAL-over-a-WAL" Paradox & Local SQLite Redundancy
Extending a Write-Ahead Log to persist directly into an external database presents critical architectural trade-offs:
- **The "WAL-over-a-WAL" Latency Collapse**: Synchronously writing WAL records across a network socket to PostgreSQL forces every write through TCP framing, SQL parsing, transaction locks, and PostgreSQL's own internal WAL (`pg_wal`) `fsync`. Write latency degrades from **$\sim 20\,\mu\text{s}$** (local NVMe sequential append) to **$2\text{--}15\,\text{ms}$**, collapsing write throughput by $100\times$ to $500\times$.
- **Inverted Failure Domains**: A local engine must remain autonomous. If the database connection pool exhausts or a network partition occurs, a synchronously coupled engine freezes and drops incoming requests.
- **Local SQLite Redundancy**: Mirroring binary WAL records to a local SQLite database on the same disk doubles write I/O and inflates storage footprints by $>2.5\times$ without providing off-box disaster recovery or high availability, while duplicating Meridian's built-in in-memory [`WALIndex`](#) B-Tree.

#### 2. The Decoupled Architecture: Fast Path + Asynchronous Persistence Sink
MeridianCore resolves this through an asynchronous, decoupled persistence tier:
1. **Local NVMe Fast Path**: [`SegmentedWALWriter`](#) writes compact 32-byte binary frames locally at native disk speed with zero network dependencies.
2. **Actor-Isolated Micro-Batching (`WALBatchCoordinator`)**: Subscribes to the record stream, accumulating records into an in-memory buffer until either a record count threshold (`maxBatchSize`, e.g. 500) or an elapsed time interval (`flushInterval`, e.g. 100ms) is reached.
3. **Pluggable Persistence Sink (`WALPersistenceSink`)**: A clean Service Provider Interface (SPI) implemented by external storage adapters (PostgreSQL, ClickHouse, S3 object storage) and embedded SQL proxies ([`SQLiteWALSink`](#)).
4. **Idempotency & Sequence Checkpointing**: Every record carries a monotonic `sequenceNumber` and `crc64` checksum. Sinks insert records with `ON CONFLICT (sequence_number) DO NOTHING` (or composite `(node_id, sequence_number)`), while tracking `lastCommittedSequenceNumber` for safe resume on restart.
5. **Embedded SQL Database Proxy (`SQLiteWALSink`)**: Leverages Darwin's native `libsqlite3` with zero third-party dependencies to serve as an in-process SQL proxy for hermetic integration testing, CI validation, and embedded analytics without requiring Docker or external PostgreSQL servers.

#### 3. Distributed Flight Recorder & Multi-Node Playback
In a distributed topology with $N$ independent nodes generating local WAL files:
- **Node Namespace Isolation**: Each node annotates its stream with a unique `nodeId`, ensuring sequence numbers do not collide in the centralized repository.
- **$K$-Way Chronological Merge**: For centralized timeline scrubbing and controlled playback, [`WALPlaybackController`](#) merges $K$ active node streams using Meridian's internal [`PriorityQueue`](#) ($O(\log K)$ min-heap by timestamp), yielding an interleaved, globally ordered event stream.

### 3.4 Standalone WAL Studio & Time-Scrubbable UI Architecture

To enable operational auditing, post-mortem incident playback, and telemetry diagnostics, `MeridianCore` and `MeridianUI` specify a standalone graphical inspection architecture ("WAL Studio") capable of scrubbing through gigabyte-scale Write-Ahead Logs in real time and decoding arbitrary binary payloads (JSON and gRPC / Protocol Buffers).

#### 1. Memory-Bounded Random Access & Scrubbing Mechanics
Attempting to load complete multi-gigabyte Write-Ahead Logs into RAM causes severe memory pressure and client-side Out-Of-Memory (OOM) crashes. The inspection architecture enforces strict memory bounds:
- **Sparse Checkpoint Index (`WALIndex`)**: Rather than buffering every record in RAM, the ingestion engine builds or reads a lightweight sparse B-Tree index mapping every $K$-th record (e.g. every 1,000 records or 5 MB of log space) from `(timestamp, sequenceNumber)` to `fileOffsetBytes`. Seeking to any point in the timeline executes an $O(\log N)$ binary search, followed by a direct file seek on the POSIX file descriptor.
- **Dual Scrubbing Semantics**:
  - **Wall-Clock Time Mode ($\Delta t$)**: The playhead moves continuously according to physical elapsed timestamps. Idle intervals where no state mutations occurred appear as flat regions, exposing realistic throughput bursts, load spikes, and system pauses.
  - **Sequence Frame Mode ($N \to N + 1$)**: The playhead advances strictly one record per tick, eliminating idle intervals. Ideal for fine-grained forensic analysis, deterministic debugging, and single-step state machine verification.
- **VCR Transport Integration**: Bridges the actor-isolated [`WALPlaybackController`](#) (virtual clock, variable speed multipliers `0.5x` to `10.0x`, forward/backward stepping) directly with [`TimelineScrubberBar`](#) and [`TimelineScrubberModel`](#) in `MeridianUI`.

#### 2. Multi-Format Payload Decoding Pipeline (JSON vs. gRPC / Protobuf)
In `WALRecord`, the message payload is stored as raw binary `Data`. The inspector provides a pluggable decoding architecture (`WALPayloadDecoder`) to rehydrate structured schemas:
- **JSON Payloads**: Parsed via `JSONSerialization`, formatted with syntax-colored indentation, and mapped into a collapsible, searchable tree hierarchy (`OutlineGroup`) supporting key/value text filtering.
- **gRPC / Protocol Buffer Payloads**:
  - **The Wire-Level Challenge**: The Protocol Buffers wire format is inherently schemaless at the byte level. Records encode numeric field tags and wire types (Varint `0`, 64-bit `1`, Length-Delimited `2`, 32-bit `5`), but omit field names, message identifiers, and enum definitions.
  - **Schema Ingestion (`.desc` vs. `.proto`)**:
    - *Compiled Descriptor Sets (`.desc` / `FileDescriptorSet`)*: The industry standard (employed by Postman and BloomRPC). Compiled via `protoc --descriptor_set_out=schemas.desc --include_imports *.proto`. SwiftProtobuf parses `Google_Protobuf_FileDescriptorSet` natively and instantaneously in pure Swift with zero external dependencies.
    - *Raw `.proto` Text Ingestion*: When users drag-and-drop raw `.proto` files, the studio triggers a local `protoc` subprocess in the background to emit an ephemeral `.desc` bundle, automatically resolving internal type definitions.
  - **The Message Type Disambiguation Problem**:
    - Heterogeneous WAL files frequently record multiple distinct message types within the same log (e.g., `OrderSubmitted`, `TradeExecuted`, `OrderCancelled`). Because raw Protobuf wire frames do not encode message type names, the studio employs a three-tier disambiguation strategy:
      1. *Envelope Type URLs*: Automatic resolution when payloads wrap `google.protobuf.Any` (extracting `type_url`).
      2. *Frame Magic / Header IDs*: Mapping 16-bit or 32-bit type IDs embedded in `WALRecord.magic` or frame prefixes to registered schemas.
      3. *Root Message Selector*: A searchable UI dropdown menu allowing the user to select the target message definition for the active record.
- **Three-Tier Graceful Degradation Strategy**:
  - **Tier 1 (Schema Available)**: Full JSON-style tree rendering with typed field names, decoded enum symbols, and nested sub-messages.
  - **Tier 2 (Schema Missing / Protobuf Detected)**: Generic Wire-Level Hierarchy displaying numeric tags, wire types, and heuristic UTF-8 string detection, accompanied by an actionable prompt to upload schemas.
  - **Tier 3 (Unknown Binary / Corrupted Payload)**: 16-byte hex dump with ASCII gutter, magic byte breakdown, and CRC-64 ECMA-182 integrity badge (Valid ✅ vs. Corrupted ⚠️).

#### 3. Three-Pane Studio Layout & Component Composition
Built using domain-agnostic `MeridianUI` primitives:
- **Top Header Bar**: Displays global WAL metadata, total records, byte size, timestamp window, and CRC-64 integrity status.
- **Left Virtual Stream Pane**: A high-performance virtualized `Table` or `LazyVStack` showing sequence numbers, timestamps, payload byte sizes, and message summaries.
- **Right Detailed Inspector Pane**: Wrapped in a resizable `Panel` using `Splitter`, presenting tabbed views for Decoded Tree, Frame Headers, and Raw Hex Dump.
- **Bottom Dock**: Houses VCR transport controls (Play, Pause, Step, Speed Multiplier) combined with `TimelineScrubberBar` rendering write-density keyframes across the elapsed duration.

---

## 4. Multi-Perspective Architectural Diagrams

### 4.1 UML Class Diagram (`classDiagram`)

```mermaid
classDiagram
    class RingBuffer~Element~ {
        +capacity: Int
        +count: Int
        +append(element: Element) Element?
        +popFirst() Element?
        +removeAll()
    }

    class CircularEventBuffer~Element: TimestampedItem~ {
        +capacity: Int
        +count: Int
        +append(event: Element)
        +events(since: Date) List~Element~
        +clear()
    }

    class BTree~Key, Value~ {
        +degree: Int
        +count: Int
        +insert(key: Key, value: Value) Value?
        +find(key: Key) Value?
        +remove(key: Key) Value?
        +scan(from: Key?, to: Key?, reverse: Bool) List~Element~
    }

    class PriorityQueue~Element~ {
        +count: Int
        +peek() Element?
        +push(element: Element)
        +pop() Element?
    }

    class CRC64 {
        <<enumeration>>
        +checksum(data: Data) UInt64
        +checksum(buffer: UnsafeRawBufferPointer) UInt64
    }

    class SegmentedWALWriter {
        +directoryURL: URL
        +currentSequence: UInt64
        +append(payload: Data) WALRecord
        +flush()
        +rotate()
    }

    class SegmentedWALReader {
        +directoryURL: URL
        +readAllRecords() List~WALRecord~
        +exportCSV(reverseOrder: Bool) String
    }

    class ReplicationBroadcaster {
        +ringBuffer: RingBuffer~WALRecord~
        +subscribe() AsyncStream~WALRecord~
        +catchUp(fromSeq: UInt64) List~WALRecord~
    }

    class ReplicationFollowerEngine {
        +lastAppliedSeq: UInt64
        +apply(record: WALRecord)
        +resetBaseline(seq: UInt64)
    }

    class WALPersistenceSink {
        <<protocol>>
        +persist(records: List~WALRecord~) async throws
        +lastCommittedSequenceNumber() async throws UInt64?
    }

    class InMemoryWALSink {
        <<actor>>
        +persistedRecords: List~WALRecord~
        +persist(records: List~WALRecord~) async throws
        +lastCommittedSequenceNumber() async throws UInt64?
        +clear()
    }

    class SQLiteWALSink {
        <<actor>>
        +databasePath: String
        +defaultNodeId: String
        +open() throws
        +persist(records: List~WALRecord~) async throws
        +persist(distributedRecords: List~DistributedWALRecord~) async throws
        +queryRecords(nodeId: String?, fromSeq: UInt64?, toSeq: UInt64?, startTime: Date?, endTime: Date?) async throws List~WALRecord~
        +queryDistributedRecords(nodeId: String?, fromSeq: UInt64?, toSeq: UInt64?, startTime: Date?, endTime: Date?) async throws List~DistributedWALRecord~
        +lastCommittedSequenceNumber() async throws UInt64?
        +count(nodeId: String?) async throws Int
        +close() throws
    }

    class WALBatchCoordinator {
        <<actor>>
        +maxBatchSize: Int
        +flushInterval: TimeInterval
        +maxRetryAttempts: Int
        +pendingCount: Int
        +submit(record: WALRecord)
        +submit(records: List~WALRecord~)
        +attach(stream: AsyncStream~WALRecord~)
        +flush() async throws
        +close() async throws
        +lastCommittedSequenceNumber() async throws UInt64?
    }

    class PostgresSchemaContract {
        <<struct>>
        +defaultTableName: String
        +createTableSQL(tableName: String, includeNodeId: Bool) String
        +createIndexSQL(tableName: String, includeNodeId: Bool) List~String~
        +insertStatementSQL(tableName: String, includeNodeId: Bool) String
        +copyCommandSQL(tableName: String, includeNodeId: Bool) String
    }

    class WALIndex {
        +checkpoints: BTree~UInt64, UInt64~
        +insert(sequence: UInt64, offset: UInt64)
        +offset(forSequence: UInt64) UInt64?
    }

    class WALPlaybackController {
        <<actor>>
        +cursor: Int
        +speedMultiplier: Double
        +recordStream: AsyncStream~WALRecord~
        +play()
        +pause()
        +step(count: Int) List~WALRecord~
        +seek(toSequence: UInt64)
        +seek(toTimestamp: Date)
    }

    class WALPayloadDecoder {
        <<protocol>>
        +canDecode(payload: Data, magic: UInt32) Bool
        +decode(payload: Data) DecodedWALMessage
    }

    class DecodedWALMessage {
        <<enumeration>>
        json
        protobuf
        rawHex
    }

    class TimelinePlaybackControlling {
        <<protocol>>
        +currentTime: Double
        +totalDuration: Double
        +isPlaying: Bool
        +speedMultiplier: Double
        +play()
        +pause()
        +seek(to: Double)
    }

    class TimelineScrubberModel {
        +currentTime: Double
        +totalDuration: Double
        +isPlaying: Bool
        +speedMultiplier: Double
        +play()
        +pause()
        +seek(to: Double)
    }

    CircularEventBuffer --> RingBuffer : encapsulates
    SegmentedWALWriter --> CRC64 : verifies integrity
    SegmentedWALReader --> CRC64 : validates checksum
    ReplicationBroadcaster --> RingBuffer : delta buffer
    WALBatchCoordinator --> WALPersistenceSink : flushes batches
    InMemoryWALSink ..|> WALPersistenceSink : implements
    SQLiteWALSink ..|> WALPersistenceSink : implements
    WALBatchCoordinator ..> PostgresSchemaContract : formatted per schema
    WALPlaybackController --> WALIndex : seeks via checkpoints
    TimelineScrubberModel ..|> TimelinePlaybackControlling : implements
```

---

### 4.2 Sequence Diagram (`sequenceDiagram`): WAL Append, Flush & Crash Recovery

```mermaid
sequenceDiagram
    autonumber
    actor Engine as Engine / Service
    participant Writer as SegmentedWALWriter
    participant Buffer as 64KB Write Buffer
    participant Disk as POSIX File System
    actor Reader as SegmentedWALReader / Recovery

    Engine->>Writer: append(payload: Data)
    Writer->>Writer: Calculate CRC64 ECMA-182
    Writer->>Buffer: pack 32B Frame Header + Payload
    alt Buffer count >= 64KB or syncPolicy == .always
        Writer->>Disk: write(contentsOf: buffer)
        opt syncPolicy == .always
            Writer->>Disk: fcntl(F_FULLFSYNC)
        end
    end
    Writer-->>Engine: WALRecord (Sequence, Offset, Size)

    Note over Disk: Process Crash / Power Cut
    Engine->>Reader: readAllRecords()
    Reader->>Disk: Read sequential frames
    Reader->>Reader: Validate Magic & Checksum CRC64
    opt Partial / Corrupted EOF Tail
        Reader->>Disk: Truncate file to last valid frame offset
        Reader->>Reader: Report clean recovery
    end
    Reader-->>Engine: Rehydrated State Stream
```

---

### 4.3 State Transition Diagram (`stateDiagram-v2`): Circuit Breaker FSM

```mermaid
stateDiagram-v2
    [*] --> Closed: Initial State

    Closed --> Open: Failure threshold exceeded (5 consecutive failures)
    Open --> HalfOpen: Reset timeout expires (e.g. 5.0 seconds)
    HalfOpen --> Closed: Probe request succeeds (health restored)
    HalfOpen --> Open: Probe request fails (fault persists)
```

---

### 4.4 Flowchart (`flowchart TD`): Distributed Multi-Node WAL Persistence & Centralized Playback Topology

```mermaid
flowchart TD
    subgraph EdgeNodes ["Distributed Edge / Worker Nodes"]
        N1["Node A (Local SegmentedWALWriter)"] -->|"AsyncStream"| C1["WALBatchCoordinator A"]
        N2["Node B (Local SegmentedWALWriter)"] -->|"AsyncStream"| C2["WALBatchCoordinator B"]
        N3["Node C (Local SegmentedWALWriter)"] -->|"AsyncStream"| C3["WALBatchCoordinator C"]
    end

    subgraph CentralStore ["Centralized Event Storage Tier"]
        C1 -->|"Micro-Batch (500 records / 100ms)"| PG[("PostgreSQL / TimescaleDB Hypertables")]
        C2 -->|"Micro-Batch (500 records / 100ms)"| PG
        C3 -->|"Micro-Batch (500 records / 100ms)"| PG
        PG --> Meta[("Playback Session State & Bookmarks")]
    end

    subgraph PlaybackTier ["Centralized Controlled Playback Engine"]
        PG -->|"Query Slice [t1, t2] (Node A, B, C)"| PQ["PriorityQueue (Min-Heap by Timestamp)"]
        PQ -->|"O(log K) Chronological Interleave"| Coordinator["Distributed Playback Coordinator"]
        Coordinator -->|"VCR Controls (Play, Step, Seek)"| Dashboard["Central Operations Dashboard"]
    end
```

---

### 4.5 Sequence Diagram (`sequenceDiagram`): Asynchronous Micro-Batch Buffering & Sink Persistence

```mermaid
sequenceDiagram
    autonumber
    actor Engine as Local Engine
    participant Writer as SegmentedWALWriter
    participant Coord as WALBatchCoordinator
    participant Sink as WALPersistenceSink (Postgres)
    participant DB as PostgreSQL Cluster

    Engine->>Writer: append(payload: Data)
    Writer->>Writer: Append 32B frame to local NVMe segment
    Writer-->>Engine: WALRecord (immediate ACK, <20µs)
    Writer-)Coord: emit(record) via AsyncStream

    Note over Coord: Accumulate in memory buffer
    alt Buffer count >= maxBatchSize (e.g. 500) OR Timer fires (100ms)
        Coord->>Sink: persist(records: batch)
        Sink->>DB: INSERT INTO meridian_wal_records ... ON CONFLICT DO NOTHING
        DB-->>Sink: Transaction Committed
        Sink-->>Coord: Success ACK
        Coord->>Coord: Advance lastCommittedSequenceNumber
    else Database Network Partition / Timeout
        Sink-->>Coord: Network Error Thrown
        Coord->>Coord: Exponential Backoff & Retry (preserve buffer)
    end
```

---

### 4.6 Sequence Diagram (`sequenceDiagram`): Interactive Timeline Scrubbing, VCR Replay & Protobuf Decoding Flow

```mermaid
sequenceDiagram
    autonumber
    actor User as User / Operator
    participant UI as WALStudioView (SwiftUI)
    participant Model as WALStudioViewModel
    participant Scrubber as TimelineScrubberBar (MeridianUI)
    participant Engine as WALPlaybackController
    participant Index as WALIndex (Sparse B-Tree)
    participant Disk as POSIX File Handle
    participant Decoder as WALPayloadDecoder

    User->>UI: Drop WAL File + schema.desc
    UI->>Model: load(walURL, schemaURL)
    Model->>Index: Build Sparse Checkpoints
    Index-->>Model: Sparse Checkpoints Ready
    Model->>Scrubber: Configure Duration & Keyframe Densities

    User->>Scrubber: Drag Playhead to Target Time T
    Scrubber->>Model: onSeek(targetTime)
    Model->>Engine: seek(toTimestamp: targetTime)
    Engine->>Index: offset(forSequence: targetSeq)
    Index-->>Engine: Byte Offset (0x01FA400)
    Engine->>Disk: seek(to: offset) and readFrame()
    Disk-->>Engine: Raw 32B Frame + Payload Data
    Engine->>Engine: Verify CRC64 ECMA-182
    Engine-->>Model: Emit WALRecord
    Model->>Decoder: decode(payload: record.payload)
    alt Payload is JSON
        Decoder-->>Model: DecodedWALMessage.json
    else Payload is Protobuf (schema.desc matched)
        Decoder-->>Model: DecodedWALMessage.protobuf
    else Schema Missing / Unknown
        Decoder-->>Model: DecodedWALMessage.rawHex
    end
    Model-->>UI: Update Inspector & Highlight Record
```

---

## 5. Distributed Resilience Mechanics

### 5.1 Exponential Backoff with Uniform Jitter
Prevents thundering-herd retry storms against recovering backend services:
$$T_k = \min\left(T_{\max}, \; T_0 \cdot 2^k\right) \times \left(1 + U(-\delta, \delta)\right)$$
Where:
- $T_0$: Base retry interval (e.g., $250\text{ ms}$)
- $T_{\max}$: Maximum capped ceiling (e.g., $10.0\text{ s}$)
- $k$: Consecutive attempt index
- $U(-\delta, \delta)$: Uniform pseudo-random distribution with jitter factor $\delta \in [0.1, 0.25]$.

### 5.2 Sliding Window Deduplication (`SlidingDeduplicator<Key>`)
Maintains an in-memory chronological index mapping unique deterministic message IDs or transaction keys to expiration timestamps:
- Evaluates incoming delivery receipts in $O(1)$ time.
- Guarantees **exactly-once processing semantics** over lossy networks delivering at-least-once message streams.
- Automatically purges expired keys via an amortized generational sweep, preventing unbounded memory leaks.

---

## 6. Verification & Test Metrics

All components in `MeridianCore` and `Resilience` pass with a **100% test pass rate** with zero compiler warnings under strict Swift 6 concurrency:

| Target Module | Test Suites | Total Tests | Pass Rate | Line Coverage |
| :--- | :---: | :---: | :---: | :---: |
| **`MeridianCore`** (DataStructures, Storage, Replication, Sinks) | 14 | 78 | **100%** | **97.77%** |
| **`Resilience`** (Supervisors, Outbox, Deduplicator) | 1 | 12 | **100%** | **96.40%** |
| **Total** | **15** | **90** | **100%** | **>97.00%** |


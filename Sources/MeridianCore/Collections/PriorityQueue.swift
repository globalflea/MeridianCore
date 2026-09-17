import Foundation

/// Priority order determining root element placement in a binary heap.
public enum PriorityOrder: Sendable, Equatable {
    /// Smallest element resides at the root (Min-Heap).
    case min
    /// Largest element resides at the root (Max-Heap).
    case max
}

/// A high-performance, array-backed binary heap priority queue.
///
/// Provides logarithmic time $O(\log N)$ insertions and root extractions, with $O(1)$ constant-time root peek.
/// Indispensable for event-time watermark sorting, out-of-order event reconstruction, best-first $k$-NN searches, and rule salience agendas.
public struct PriorityQueue<Element: Sendable>: Sendable {
    private var heap: [Element] = []
    private let areInIncreasingOrder: @Sendable (Element, Element) -> Bool

    /// Initializes a priority queue with a custom comparator predicate.
    ///
    /// - Parameter comparator: A predicate that returns `true` if its first argument should be ordered before its second argument.
    public init(comparator: @escaping @Sendable (Element, Element) -> Bool) {
        self.areInIncreasingOrder = comparator
    }

    /// Initializes an empty `PriorityQueue` with a custom priority ordering closure.
    ///
    public init(sort areInIncreasingOrder: @escaping @Sendable (Element, Element) -> Bool) {
        self.areInIncreasingOrder = areInIncreasingOrder
    }

    /// Initializes a priority queue populated with elements using a custom comparator.
    /// - Parameters:
    ///   - elements: Initial elements to populate into the heap.
    ///   - comparator: Priority order comparator.
    public init(elements: [Element], comparator: @escaping @Sendable (Element, Element) -> Bool) {
        self.areInIncreasingOrder = comparator
        self.heap = elements
        if heap.count > 1 {
            for i in stride(from: (heap.count / 2) - 1, through: 0, by: -1) {
                siftDown(from: i)
            }
        }
    }

    /// Number of elements currently stored in the priority queue.
    public var count: Int {
        return heap.count
    }

    /// All elements currently stored in the internal heap buffer.
    public var elements: [Element] {
        heap
    }

    /// Whether the priority queue contains zero elements.
    public var isEmpty: Bool {
        return heap.isEmpty
    }

    /// Returns the highest-priority root element in $O(1)$ time without removing it.
    public func peek() -> Element? {
        return heap.first
    }

    /// Pushes a new element into the priority queue in $O(\log N)$ time.
    public mutating func push(_ element: Element) {
        heap.append(element)
        siftUp(from: heap.count - 1)
    }

    /// Removes and returns the highest-priority root element in $O(\log N)$ time.
    ///
    /// - Returns: The extracted root element, or `nil` if the queue is empty.
    @discardableResult
    public mutating func pop() -> Element? {
        guard !heap.isEmpty else { return nil }
        if heap.count == 1 {
            return heap.removeLast()
        }
        heap.swapAt(0, heap.count - 1)
        let root = heap.removeLast()
        siftDown(from: 0)
        return root
    }

    /// Clears all elements from the priority queue.
    public mutating func removeAll() {
        heap.removeAll()
    }

    /// Clears all elements from the priority queue (alias for `removeAll()`).
    public mutating func clear() {
        heap.removeAll()
    }

    // MARK: - Binary Heap Sifting

    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = (child - 1) / 2
        while child > 0 && areInIncreasingOrder(heap[child], heap[parent]) {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent

            if left < heap.count && areInIncreasingOrder(heap[left], heap[candidate]) {
                candidate = left
            }
            if right < heap.count && areInIncreasingOrder(heap[right], heap[candidate]) {
                candidate = right
            }
            if candidate == parent {
                return
            }
            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}

extension PriorityQueue where Element: Comparable {
    /// Initializes an empty priority queue for comparable elements with min-heap ordering.
    public init() {
        self.init(order: .min)
    }

    /// Initializes a priority queue with default min-heap or max-heap ordering.
    ///
    /// - Parameter order: `.min` for min-heap (default), `.max` for max-heap.
    public init(order: PriorityOrder = .min) {
        switch order {
        case .min:
            self.init(comparator: { $0 < $1 })
        case .max:
            self.init(comparator: { $0 > $1 })
        }
    }

    /// Initializes a priority queue with elements using default min-heap or max-heap ordering.
    /// - Parameters:
    ///   - elements: Initial elements to populate into the heap.
    ///   - order: `.min` for min-heap (default), `.max` for max-heap.
    public init(elements: [Element], order: PriorityOrder = .min) {
        switch order {
        case .min:
            self.init(elements: elements, comparator: { $0 < $1 })
        case .max:
            self.init(elements: elements, comparator: { $0 > $1 })
        }
    }
}

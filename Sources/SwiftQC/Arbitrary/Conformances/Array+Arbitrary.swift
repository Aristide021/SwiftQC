//
//  Array+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen // Assuming this is PointFree's Gen

/// A helper shrinker for arrays that wraps an `any Shrinker` for its elements.
fileprivate struct ArrayElementShrinker<ElementValue>: Shrinker {
    typealias Value = [ElementValue]
    private let elementShrinker: any Shrinker<ElementValue>

    init(elementShrinker: any Shrinker<ElementValue>) {
        self.elementShrinker = elementShrinker
    }

    public func shrink(_ value: [ElementValue]) -> [[ElementValue]] {
        var shrunkArrays: [[ElementValue]] = []

        // Strategy 1: Reduce array length
        // A. Shrink to empty array (if not already empty)
        if !value.isEmpty {
            shrunkArrays.append([])
        }

        // B. Halve the array (if count > 1)
        if value.count > 1 {
            let half = Array(value.prefix(value.count / 2))
            // Ensure it's actually smaller and not a duplicate of the empty array if value.count was 1
            if half.count < value.count {
                shrunkArrays.append(half)
            }
        }

        // C. Remove one element from the end (if not empty)
        if !value.isEmpty {
            var oneLess = value
            oneLess.removeLast()
            // Ensure it's actually smaller
            if oneLess.count < value.count {
                 shrunkArrays.append(oneLess)
            }
        }

        // D. Remove one element from the beginning (if count > 1 to be distinct from C for single element array)
        if value.count > 1 {
            var oneLessFromFront = value
            oneLessFromFront.removeFirst()
            // Ensure it's actually smaller
            if oneLessFromFront.count < value.count {
                shrunkArrays.append(oneLessFromFront)
            }
        }

        // Strategy 2: Shrink individual elements
        for i in value.indices {
            let originalElement = value[i]
            for shrunkElement in self.elementShrinker.shrink(originalElement) {
                var newArray = value
                newArray[i] = shrunkElement
                shrunkArrays.append(newArray)
            }
        }

        // Optional: Minimal deduplication for immediately obvious duplicates
        // This simple deduplication pass does not require Equatable/Hashable on ElementValue itself,
        // as it relies on the array of shrunk arrays. However, for complex ElementValue types,
        // this might not be perfectly efficient or catch all logical duplicates.
        // A more robust deduplication would indeed require Equatable/Hashable.
        // For now, we'll return potentially duplicate arrays, which is acceptable.
        // The property runner might have its own mechanisms to avoid re-testing identical states.

        // Sorting by count can be a good heuristic for the shrinker to offer
        // "simpler" shrinks first. This doesn't require Equatable/Hashable.
        return shrunkArrays.sorted { $0.count < $1.count }
    }
}

extension Array: Arbitrary where Element: Arbitrary {
    public typealias Value = [Element.Value]

    public static var gen: Gen<[Element.Value]> {
        let countGenerator = Gen.int(in: 0...100)
        return Element.gen.array(of: countGenerator)
    }

    public static var shrinker: any Shrinker<[Element.Value]> {
        return ArrayElementShrinker<Element.Value>(elementShrinker: Element.shrinker)
    }
}
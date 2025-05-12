//
//  Set+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen

// Use ElementType as the generic parameter name inside the shrinker
fileprivate struct SetShrinker<ElementType: Hashable & Sendable>: Shrinker {
    // SetValue is Set<ElementType>
    typealias Value = Set<ElementType>

    private let elementShrinker: any Shrinker<ElementType>

    init(elementShrinker: any Shrinker<ElementType>) {
        self.elementShrinker = elementShrinker
    }

    func shrink(_ set: Set<ElementType>) -> [Set<ElementType>] { // Use Set<ElementType> explicitly
        guard !set.isEmpty else { return [] }

        var shrinks: [Set<ElementType>] = []
        shrinks.append([]) // Offer empty set

        if set.count > 1 { // Offer half
            // elements is Array<ElementType>
            let elements = Array(set)
            // halfElements is Array<ElementType>
            let halfElements = Array(elements.prefix(elements.count / 2))
            // Set initializer expects a Sequence whose Element is ElementType
            let halfSet = Set(halfElements) // This should now work
            if halfSet.count < set.count { shrinks.append(halfSet) }
        }

        if set.count >= 1 { // Offer one less
            var oneLess = set
            if let first = set.first { oneLess.remove(first); if oneLess.count < set.count { shrinks.append(oneLess) } }
        }

        // element is ElementType
        for element in set {
            // shrunkElement is ElementType
            for shrunkElement in elementShrinker.shrink(element) {
                var newSet = set; newSet.remove(element); newSet.insert(shrunkElement)
                shrinks.append(newSet)
            }
        }
        return shrinks.sorted { $0.count < $1.count }
    }
}

// Constraint remains: Element is Arbitrary, Element.Value is Hashable (and Sendable from Arbitrary)
extension Set: Arbitrary where Element: Arbitrary, Element.Value: Hashable {

    // Arbitrary.Value is Set<Element.Value>
    public typealias Value = Set<Element.Value>

    public static var gen: Gen<Value> { // Return type is Gen<Set<Element.Value>>
        let countGen = Gen.int(in: 0...50)
        // Element.gen produces Gen<Element.Value>
        // array(of:) produces Gen<[Element.Value]>
        let elementArrayGen = Element.gen.array(of: countGen)
        // map takes [Element.Value] and produces Set<Element.Value>
        return elementArrayGen.map(Set<Element.Value>.init) // Explicit type for init
    }

    public static var shrinker: any Shrinker<Value> { // Return type is any Shrinker<Set<Element.Value>>
        // Pass Element.shrinker (any Shrinker<Element.Value>)
        // Instantiate SetShrinker<Element.Value>
        SetShrinker<Element.Value>(elementShrinker: Element.shrinker)
    }
}
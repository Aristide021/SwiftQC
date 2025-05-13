//
//  ContiguousArray+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen

fileprivate struct ContiguousArrayShrinker<ElementConformant: Arbitrary>: Shrinker 
    where ElementConformant.Value: Hashable {

    public typealias Value = ContiguousArray<ElementConformant.Value>
    private let elementShrinker: any Shrinker<ElementConformant.Value>

    public init() { 
        self.elementShrinker = ElementConformant.shrinker
    }

    public func shrink(_ caValue: ContiguousArray<ElementConformant.Value>) -> [ContiguousArray<ElementConformant.Value>] {
        let arrayEquivalent = Array(caValue)
        var shrunkSwiftArrays: [[ElementConformant.Value]] = []

        if !arrayEquivalent.isEmpty {
            shrunkSwiftArrays.append([])
        }
        if arrayEquivalent.count > 1 {
            shrunkSwiftArrays.append(Array(arrayEquivalent.prefix(arrayEquivalent.count / 2)))
        }
        if !arrayEquivalent.isEmpty {
            shrunkSwiftArrays.append(Array(arrayEquivalent.dropLast()))
        }
        
        for i in arrayEquivalent.indices {
            let originalElement = arrayEquivalent[i]
            for shrunkElement in self.elementShrinker.shrink(originalElement) {
                var newArrayElements = arrayEquivalent
                newArrayElements[i] = shrunkElement
                shrunkSwiftArrays.append(newArrayElements)
            }
        }
        
        var uniqueShrinks = [ContiguousArray<ElementConformant.Value>]()
        // ContiguousArray is Hashable if its Element is Hashable. ElementConformant.Value is Hashable here.
        var seen = Set<ContiguousArray<ElementConformant.Value>>() 
        
        for swiftArray in shrunkSwiftArrays {
            let contiguousShrink = ContiguousArray(swiftArray)
            if seen.insert(contiguousShrink).inserted {
                uniqueShrinks.append(contiguousShrink)
            }
        }
        
        return uniqueShrinks.sorted { $0.count < $1.count }
    }
}

extension ContiguousArray: Arbitrary where Element: Arbitrary, Element.Value: Hashable {
    // Element is the type parameter of ContiguousArray<Element>, and this Element type conforms to Arbitrary.
    // Arbitrary.Value is ContiguousArray<Element.Value>
    public typealias Value = ContiguousArray<Element.Value>

    public static var gen: Gen<Value> { // Gen<ContiguousArray<Element.Value>>
        let countGenerator = Gen.int(in: 0...100)
        // Element.gen produces Gen<Element.Value>
        // .array(of:) on Gen<Element.Value> produces Gen<[Element.Value]>
        // The map closure takes [Element.Value] and returns ContiguousArray<Element.Value>
        return Element.gen.array(of: countGenerator).map { (elements: [Element.Value]) -> ContiguousArray<Element.Value> in
            return ContiguousArray<Element.Value>(elements)
        }
    }

    public static var shrinker: any Shrinker<Value> { // any Shrinker<ContiguousArray<Element.Value>>
        return ContiguousArrayShrinker<Element>()
    }
}
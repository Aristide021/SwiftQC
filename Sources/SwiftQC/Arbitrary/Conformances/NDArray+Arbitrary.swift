/*import Gen
import SwiftQC // Assuming NDArray is defined within the SwiftQC module

/// Shrinks an NDArray towards smaller shapes and simpler element values.
public struct NDArrayShrinker<E: Arbitrary>: Shrinker where E.Value: Hashable { // Simplified constraint
    // NDArray<E.Value> needs to be the Value type associated with the Shrinker
    public typealias Value = NDArray<E.Value>

    private let elementShrinker: any Shrinker<E.Value>

    public init() {
        self.elementShrinker = E.shrinker
    }

    public func shrink(_ ndValue: Value) -> [Value] {
        var shrinks: [Value] = []
        guard ndValue.count > 0 else { return [] } // Cannot shrink empty array

        // --- Shrinking strategies --- 

        // Strategy 1: Shrink Dimensions (Simplified for Rank 2)
        if ndValue.rank == 2 {
            let rows = ndValue.shape[0]
            let cols = ndValue.shape[1]

            // Shrink rows
            if rows > 1 {
                shrinks.append(ndValue[0..<rows-1, 0..<cols]) // Remove last row
                if rows > 1 { shrinks.append(ndValue[0..<1, 0..<cols]) } // Shrink to 1 row
            }
            // Shrink columns
            if cols > 1 {
                 shrinks.append(ndValue[0..<rows, 0..<cols-1]) // Remove last col
                 if cols > 1 { shrinks.append(ndValue[0..<rows, 0..<1]) } // Shrink to 1 col
            }
        }
        // TODO: Add dimension shrinking for higher ranks if needed

        // Add a 1x1 array with a shrunk element
        if !(ndValue.rank == ndValue.shape.count && ndValue.shape.allSatisfy { $0 == 1 }) {
            if let firstElement = ndValue.elements.first {
                 for shrunkElement in elementShrinker.shrink(firstElement) {
                    let oneShape = Array(repeating: 1, count: ndValue.rank)
                    if let oneArray = try? NDArray<E.Value>(shape: oneShape, elements: [shrunkElement]) {
                        shrinks.append(oneArray)
                        break
                    }
                }
            }
        }

        // Strategy 2: Shrink Individual Elements
        for (index, element) in ndValue.elements.enumerated() {
            for shrunkElement in elementShrinker.shrink(element) {
                var newElements = ndValue.elements
                newElements[index] = shrunkElement
                // Ensure elements match shape count before creating
                if newElements.count == ndValue.shape.reduce(1, *), 
                   let newArray = try? NDArray(shape: ndValue.shape, elements: newElements) {
                    shrinks.append(newArray)
                }
            }
        }

        // Strategy 3: Shrink towards a zero/default array
        if let firstElement = ndValue.elements.first {
            // Find a minimal element (one that doesn't shrink further, or a default)
            let minimalElementCandidates = elementShrinker.shrink(firstElement)
            let zeroElement = minimalElementCandidates.first { elementShrinker.shrink($0).isEmpty } ?? E.gen.run()

            let zeroElements = Array(repeating: zeroElement, count: ndValue.count)
            if zeroElements.count == ndValue.shape.reduce(1, *), // Ensure count matches shape
               let zeroArray = try? NDArray(shape: ndValue.shape, elements: zeroElements), zeroArray != ndValue {
                 shrinks.append(zeroArray)
            }
        }

        // Deduplicate using Hashable conformance of NDArray (requires Element: Hashable)
        // Filter out shrinks identical to the original value
        return Array(Set(shrinks.filter { $0 != ndValue }))
    }
}

// NDArray itself needs Equatable and Hashable conformance
// extension NDArray: Equatable where Element: Equatable {}
// extension NDArray: Hashable where Element: Hashable {}

extension NDArray: Arbitrary where Element: Arbitrary, Element: Hashable {
    public typealias Value = NDArray<Element>

    public static var gen: Gen<NDArray<Element>> {
        let shapeGen = Gen.frequency([
            (1, Gen.always([1,1])), // Bias towards 1x1
            (2, Gen.int(in: 1...5).map { [1, $0] }), // Row vector
            (2, Gen.int(in: 1...5).map { [$0, 1] }), // Col vector
            (5, zip(Gen.int(in: 1...5), Gen.int(in: 1...5)).map { [$0, $1] })
        ])

        return shapeGen.flatMap { shape -> Gen<NDArray<Element>> in
            let count = shape.reduce(1, *)
            guard count > 0 else {
                // Handle empty shape case if necessary, maybe return empty NDArray
                // For now, assume shape dimensions are >= 1 from generator
                print("Warning: NDArray gen produced empty shape \(shape).")
                return Gen.always(try! NDArray(shape: [1,1], elements: [Element.gen.run()])) // Fallback
            }
            
            let elementsGen = Gen.collection(of: Element.gen, counts: count...count)

            return elementsGen.flatMap { elements -> Gen<NDArray<Element>> in
                // Double-check element count before creating NDArray
                if elements.count == count,
                   let ndArray = try? NDArray(shape: shape, elements: elements) {
                    return Gen.always(ndArray)
                } else {
                    print("Warning: NDArray gen fallback. Shape: \(shape), ElemCount: \(elements.count), Expected: \(count).")
                    return Gen.always(try! NDArray(shape: [1,1], elements: [Element.gen.run()]))
                }
            }
        }
    }

    public static var shrinker: any Shrinker<NDArray<Element>> {
        NDArrayShrinker<Element>()
    }
}

// Helper to get the Arbitrary metatype if needed, though likely not required here
extension Arbitrary {
     typealias ArbitraryMetatype = Self
}

// Note: NDArray needs to be Equatable (requires Element: Equatable) for the shrinker's
// duplicate removal and some checks. It also needs to be Hashable for efficient
// duplicate removal in the shrinker. If not, alternative de-duplication is needed.
// The conformance `where Element: Arbitrary, Element: Equatable` reflects this.
*/
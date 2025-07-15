import SwiftQC
import Testing
import Gen

// MARK: - Basic Property Testing Examples

@Test("Integer addition is commutative")
func testIntegerAdditionCommutative() async {
  // Simple example: test two fixed values  
  _ = await forAll("Addition is commutative for any integer") { (x: Int) in
    let y = 42
    #expect(x + y == y + x)
  }
}

@Test("String length is preserved under reversal")
func testStringReversalLength() async {
  _ = await forAll("String reversal preserves length") { (s: String) in
    let reversed = String(s.reversed())
    #expect(s.count == reversed.count)
  }
}

@Test("Array count is non-negative")
func testArrayCountNonNegative() async {
  _ = await forAll("Array count is always non-negative") { (arr: [Int]) in
    #expect(arr.count >= 0)
  }
}

@Test("Boolean properties")
func testBooleanProperties() async {
  _ = await forAll("Boolean identity") { (b: Bool) in
    #expect(b == b)
  }
}

// MARK: - Custom Types Example

struct SimplePoint: Arbitrary, Sendable, Equatable {
  let x: Int
  let y: Int
  
  typealias Value = SimplePoint
  
  static var gen: Gen<SimplePoint> {
    zip(Int.gen, Int.gen).map { SimplePoint(x: $0, y: $1) }
  }
  
  static var shrinker: any Shrinker<SimplePoint> {
    SimplePointShrinker()
  }
}

struct SimplePointShrinker: Shrinker {
  typealias Value = SimplePoint
  
  func shrink(_ value: SimplePoint) -> [SimplePoint] {
    var results: [SimplePoint] = []
    
    // Shrink to origin
    if value.x != 0 || value.y != 0 {
      results.append(SimplePoint(x: 0, y: 0))
    }
    
    // Shrink x coordinate
    for newX in Shrinkers.int.shrink(value.x) {
      results.append(SimplePoint(x: newX, y: value.y))
    }
    
    // Shrink y coordinate  
    for newY in Shrinkers.int.shrink(value.y) {
      results.append(SimplePoint(x: value.x, y: newY))
    }
    
    return results
  }
}

@Test("Custom point equality")
func testCustomPointEquality() async {
  _ = await forAll("Point equals itself") { (p: SimplePoint) in
    #expect(p == p)
  }
}
import SwiftQC
import Testing
import Gen

// MARK: - Testing New Ergonomic Improvements

@Test("Type inference works for simple cases")
func testTypeInference() async {
  // This should now work without explicit type annotation!
  _ = await forAll("Addition is commutative for any integer") { (x: Int) in
    let y = 42
    #expect(x + y == y + x)
  }
}

@Test("String properties with type inference")
func testStringTypeInference() async {
  _ = await forAll("String reversal preserves length") { (s: String) in
    let reversed = String(s.reversed())
    #expect(s.count == reversed.count)
  }
}

@Test("Array properties with type inference")
func testArrayTypeInference() async {
  _ = await forAll("Array count is always non-negative") { (arr: [Int]) in
    #expect(arr.count >= 0)
  }
}

@Test("Boolean properties with type inference")
func testBooleanTypeInference() async {
  _ = await forAll("Boolean identity") { (b: Bool) in
    #expect(b == b)
  }
}

// MARK: - Custom Types with New Shrinker Combinators

struct ErgonomicPoint: Arbitrary, Sendable, Equatable {
  let x: Int
  let y: Int
  
  typealias Value = ErgonomicPoint
  
  static var gen: Gen<ErgonomicPoint> {
    zip(Int.gen, Int.gen).map { ErgonomicPoint(x: $0, y: $1) }
  }
  
  // Using the new combinator API!
  static var shrinker: any Shrinker<ErgonomicPoint> {
    Shrinkers.map(
      from: Shrinkers.tuple(Shrinkers.int, Shrinkers.int),
      transform: { ErgonomicPoint(x: $0.0, y: $0.1) },
      reverse: { ($0.x, $0.y) }
    )
  }
}

@Test("Custom point with ergonomic shrinker")
func testCustomPointWithErgonomicShrinker() async {
  _ = await forAll("Point equals itself") { (p: ErgonomicPoint) in
    #expect(p == p)
  }
}

// MARK: - Multi-parameter Tests with Clearer API

@Test("Two parameter test with clear API")
func testTwoParametersClear() async {
  // Using the new labeled parameter API
  _ = await forAll("Addition is commutative", types: Int.self, Int.self) { (a: Int, b: Int) in
    #expect(a + b == b + a)
  }
}

@Test("Three parameter test with clear API") 
func testThreeParametersClear() async {
  _ = await forAll("Addition is associative", types: Int.self, Int.self, Int.self) { (a: Int, b: Int, c: Int) in
    #expect((a + b) + c == a + (b + c))
  }
}
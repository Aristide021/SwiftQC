//
//  ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import XCTest
@testable import SwiftQC
import Gen
import Foundation // For Decimal, UUID
#if canImport(CoreGraphics)
import CoreGraphics // For CGFloat
#endif

// NoShrink is assumed to be defined elsewhere

final class ArbitraryTests: XCTestCase {

    private func newRng(seed: UInt64 = 0) -> Xoshiro {
        return Xoshiro(seed: seed)
    }

    // MARK: - Int Arbitrary Tests (Condensed)
    func testIntArbitrary_gen() { var r=newRng();let g=Int.gen;var s=Set<Int>();for _ in 0..<100{s.insert(g.run(using:&r))};XCTAssertGreaterThan(s.count,1)}
    func testIntArbitrary_shrinker() {let s=Int.shrinker;XCTAssertTrue(s.shrink(0).isEmpty);let pS=s.shrink(10);XCTAssertFalse(pS.isEmpty);XCTAssertTrue(pS.contains(0));XCTAssertTrue(pS.allSatisfy{abs($0)<10||$0==0});let nS=s.shrink(-10);XCTAssertFalse(nS.isEmpty);XCTAssertTrue(nS.contains(0));XCTAssertTrue(nS.allSatisfy{abs($0)<10||$0==0})}
    func testIntArbitrary_forAllSimpleProperty() async { let r=await forAll("Int:n==n",{(n:Int)in XCTAssertEqual(n,n)},Int.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}

    // MARK: - Bool Arbitrary Tests (Condensed)
    func testBoolArbitrary_gen(){var r=newRng();let g=Bool.gen;var t=false;var f=false;for _ in 0..<100{let v=g.run(using:&r);if v{t=true}else{f=true}};XCTAssertTrue(t&&f)}
    func testBoolArbitrary_shrinker(){let s=Bool.shrinker;XCTAssertEqual(s.shrink(true),[false]);XCTAssertTrue(s.shrink(false).isEmpty)}
    func testBoolArbitrary_forAllSimpleProperty()async{let r=await forAll("Bool:b||!b",{(b:Bool)in XCTAssertTrue(b || !b)},Bool.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}

    // MARK: - String Arbitrary Tests (Condensed)
    func testStringArbitrary_gen(){var r=newRng();let g=String.gen;var s=Set<String>();for _ in 0..<50{s.insert(g.run(using:&r))};XCTAssertGreaterThan(s.count,1);XCTAssertTrue(s.allSatisfy{$0.count>=0&&$0.count<=100})}
    func testStringArbitrary_shrinker(){let s=String.shrinker;XCTAssertTrue(s.shrink("").isEmpty);let sH=s.shrink("hello");XCTAssertFalse(sH.isEmpty);XCTAssertTrue(sH.contains(""));XCTAssertTrue(sH.allSatisfy{$0.count<"hello".count||$0.isEmpty})}
    func testStringArbitrary_forAllSimpleProperty()async{let r=await forAll("String:s.c>=0",{(s:String)in XCTAssertGreaterThanOrEqual(s.count,0)},String.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}

    // MARK: - Array<Int> Arbitrary Tests (Condensed)
    func testArrayIntArbitrary_gen(){var r=newRng();let g=Array<Int>.gen;var nE=false;var tC=0;for _ in 0..<30{let a=g.run(using:&r);if !a.isEmpty{nE=true};tC+=a.count;XCTAssertTrue(a.count<=100)};XCTAssertTrue(nE||tC==0)}
    func testArrayIntArbitrary_shrinker(){let s=Array<Int>.shrinker;XCTAssertTrue(s.shrink([]).isEmpty);let aS=[10,20,0];let sA=s.shrink(aS);XCTAssertFalse(sA.isEmpty);XCTAssertTrue(sA.contains([]));let oL=Array(aS.dropLast());XCTAssertTrue(sA.contains(oL)||oL.isEmpty&&sA.contains([]));XCTAssertTrue(sA.contains([0,20,0])||sA.contains([Int.shrinker.shrink(10).first ?? 10,20,0]))}
    func testArrayIntArbitrary_forAllSimpleProperty()async{let r=await forAll("Arr<Int>:rr==o",{(a:[Int])in XCTAssertEqual(a.reversed().reversed(),a)},[Int].self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}

    // MARK: - Optional<String> Arbitrary Tests (Condensed)
    func testOptionalStringArbitrary_gen(){var r=newRng();let g=Optional<String>.gen;var n=false;var s=false;for _ in 0..<100{let oV=g.run(using:&r);if oV==nil{n=true}else{s=true;XCTAssertNotNil(oV)}};XCTAssertTrue(n);XCTAssertTrue(s)}
    func testOptionalStringArbitrary_shrinker(){let s=Optional<String>.shrinker;XCTAssertTrue(s.shrink(nil).isEmpty);let sV:String?="test";let sS=s.shrink(sV);XCTAssertFalse(sS.isEmpty);XCTAssertTrue(sS.contains(nil));if let sW=String.shrinker.shrink("test").first{XCTAssertTrue(sS.contains(Optional(sW)))}}
    func testOptionalStringArbitrary_forAllSimpleProperty()async{let r=await forAll("Opt<Str>:map",{(oS:String?)in let m=oS.map{$0+"!"};if oS != nil{XCTAssertNotNil(m)}else{XCTAssertNil(m)}},Optional<String>.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(String(describing:v)) E:\(e)")}}

    // MARK: - Result<Int, TestErrorForArbitrary> Arbitrary Tests (Condensed)
    enum TestErrorForArbitrary:Error,CaseIterable,Equatable,Arbitrary,Sendable{case oops,whoops;typealias Value=TestErrorForArbitrary;static var gen:Gen<TestErrorForArbitrary>{guard !allCases.isEmpty else{fatalError()};return Gen.element(of:allCases).compactMap{$0}};static var shrinker:any Shrinker<TestErrorForArbitrary>{NoShrink<TestErrorForArbitrary>()}}
    func testResultIntTestErrorArbitrary_gen(){var r=newRng();typealias TRT=Result<Int,TestErrorForArbitrary>;let g=TRT.gen;var sS=false;var sF=false;for _ in 0..<100{let rV=g.run(using:&r);switch rV{case .success:sS=true;case .failure:sF=true}};XCTAssertTrue(sS);XCTAssertTrue(sF)}
    func testResultIntTestErrorArbitrary_shrinker(){typealias TRT=Result<Int,TestErrorForArbitrary>;let s=TRT.shrinker;let sV:TRT = .success(10);let sS=s.shrink(sV);if let fS=Int.shrinker.shrink(10).first{XCTAssertTrue(sS.contains(.success(fS)))}else if !Int.shrinker.shrink(10).isEmpty{XCTAssertFalse(sS.isEmpty)}else{XCTAssertTrue(sS.isEmpty)};let fV:TRT = .failure(.oops);XCTAssertTrue(s.shrink(fV).isEmpty);let mS:TRT = .success(0);XCTAssertTrue(s.shrink(mS).isEmpty)}
    func testResultIntTestErrorArbitrary_forAllSimpleProperty()async{typealias TRT=Result<Int,TestErrorForArbitrary>;let r=await forAll("Res<I,TE>:isSorF",{(res:TRT)in let iS=if case .success=res{true}else{false};let iF=if case .failure=res{true}else{false};XCTAssertTrue(iS || iF);XCTAssertFalse(iS && iF)},TRT.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}} // Corrected whitespace

    // MARK: - Dictionary Arbitrary Tests (Condensed)
    func testArbitraryDictionary_gen(){var r=newRng();let g=ArbitraryDictionary<String,Int>.gen;var gNE=false;for _ in 0..<30{let d=g.run(using:&r);if !d.isEmpty{gNE=true};XCTAssertTrue(d.count<=50)};XCTAssertTrue(gNE)}
    func testArbitraryDictionary_shrinker(){let s=ArbitraryDictionary<String,Int>.shrinker;XCTAssertTrue(s.shrink([:]).isEmpty);let dS:Dictionary<String,Int>=["a":10,"b":20,"c":0];let sD=s.shrink(dS);XCTAssertFalse(sD.isEmpty);XCTAssertTrue(sD.contains([:]));XCTAssertTrue(sD.contains(where:{$0.count<dS.count && $0.count > 0}));XCTAssertTrue(sD.contains(["a":0,"b":20,"c":0])||sD.contains(["a":Int.shrinker.shrink(10).first ?? 10,"b":20,"c":0]))}
    func testArbitraryDictionary_forAllSimpleProperty()async{let r=await forAll("Dict(S,I)prop",{(d:Dictionary<String,Int>)in XCTAssertNotNil(d);for(k,v)in d{XCTAssertNotNil(k);XCTAssertNotNil(v)}},ArbitraryDictionary<String,Int>.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}

    // MARK: - Fixed-Width Integer Arbitrary Tests (Condensed)
    func testInt8Arbitrary_gen(){var r=newRng();let g=Int8.gen;var v=Set<Int8>();for _ in 0..<200{v.insert(g.run(using:&r))};XCTAssertGreaterThan(v.count,1);if !v.isEmpty{XCTAssertTrue(v.contains(Int8.min)||v.contains(Int8.max)||v.count>50)}}
    func testInt8Arbitrary_shrinker(){let s=Int8.shrinker;XCTAssertTrue(s.shrink(0).isEmpty);XCTAssertTrue(s.shrink(1).contains(0));XCTAssertTrue(s.shrink(-1).contains(0));let sP=s.shrink(100);XCTAssertTrue(sP.contains(0)&&sP.allSatisfy{abs($0)<100||$0==0});let sM=s.shrink(-100);XCTAssertTrue(sM.contains(0)&&sM.allSatisfy{abs($0)<100||$0==0})}
    func testInt8Arbitrary_forAllSimpleProperty()async{let r=await forAll("Int8:n==n",{(n:Int8)in XCTAssertEqual(n,n)},Int8.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}
    func testUInt8Arbitrary_gen(){var r=newRng();let g=UInt8.gen;var v=Set<UInt8>();for _ in 0..<200{v.insert(g.run(using:&r))};XCTAssertGreaterThan(v.count,1);if !v.isEmpty{XCTAssertTrue(v.contains(UInt8.min)||v.contains(UInt8.max)||v.count>50)}}
    func testUInt8Arbitrary_shrinker(){let s=UInt8.shrinker;XCTAssertTrue(s.shrink(0).isEmpty);XCTAssertTrue(s.shrink(1).contains(0));let sP=s.shrink(200);XCTAssertTrue(sP.contains(0)&&sP.allSatisfy{$0<200||$0==0})}
    func testUInt8Arbitrary_forAllSimpleProperty()async{let r=await forAll("UInt8:n==n",{(n:UInt8)in XCTAssertEqual(n,n)},UInt8.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}
    func testInt64Arbitrary_gen(){var r=newRng();let g=Int64.gen;var v=Set<Int64>();for _ in 0..<100{v.insert(g.run(using:&r))};XCTAssertGreaterThan(v.count,1)}
    func testInt64Arbitrary_shrinker(){let s=Int64.shrinker;XCTAssertTrue(s.shrink(0).isEmpty);XCTAssertTrue(s.shrink(1).contains(0));let sP=s.shrink(10000);XCTAssertTrue(sP.contains(0)&&sP.allSatisfy{abs($0)<10000||$0==0})}
    func testInt64Arbitrary_forAllSimpleProperty()async{let r=await forAll("Int64:n==n",{(n:Int64)in XCTAssertEqual(n,n)},Int64.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}

    // --- Int16 ---
    func testInt16Arbitrary_gen() {
        var rng = newRng()
        let gen = Int16.gen
        var values = Set<Int16>()
        for _ in 0..<200 { // Iterate enough to see variation
            values.insert(gen.run(using: &rng))
        }
        XCTAssertGreaterThan(values.count, 1, "Int16.gen should produce varied values.")
        // Check if min/max are generated or if there's a good spread for smaller ranges
        if !values.isEmpty {
             XCTAssertTrue(values.contains(Int16.min) || values.contains(Int16.max) || values.count > 50, "Should see min/max or many distinct values for Int16")
        }
    }
    func testInt16Arbitrary_shrinker() {
        let shrinker = Int16.shrinker
        XCTAssertTrue(shrinker.shrink(0).isEmpty)
        XCTAssertTrue(shrinker.shrink(1).contains(0))
        XCTAssertTrue(shrinker.shrink(-1).contains(0))
        let shrunkPositive = shrinker.shrink(1000)
        XCTAssertTrue(shrunkPositive.contains(0) && shrunkPositive.allSatisfy { abs($0) < 1000 || $0 == 0 })
        let shrunkNegative = shrinker.shrink(-1000)
        XCTAssertTrue(shrunkNegative.contains(0) && shrunkNegative.allSatisfy { abs($0) < 1000 || $0 == 0 })
    }
    func testInt16Arbitrary_forAllSimpleProperty() async {
        let result = await forAll("Int16: n == n", { (n: Int16) in XCTAssertEqual(n, n) }, Int16.self)
        if case .falsified(let v, let e, _, _) = result { XCTFail("Prop failed for Int16: \(v), err: \(e)")}
    }

    // --- UInt16 ---
    func testUInt16Arbitrary_gen() {
        var rng = newRng()
        let gen = UInt16.gen
        var values = Set<UInt16>()
        for _ in 0..<200 {
            values.insert(gen.run(using: &rng))
        }
        XCTAssertGreaterThan(values.count, 1)
        if !values.isEmpty {
             XCTAssertTrue(values.contains(UInt16.min) || values.contains(UInt16.max) || values.count > 50, "Should see min/max or many distinct values for UInt16")
        }
    }
    func testUInt16Arbitrary_shrinker() {
        let shrinker = UInt16.shrinker
        XCTAssertTrue(shrinker.shrink(0).isEmpty)
        XCTAssertTrue(shrinker.shrink(1).contains(0))
        let shrunkPositive = shrinker.shrink(2000)
        XCTAssertTrue(shrunkPositive.contains(0) && shrunkPositive.allSatisfy { $0 < 2000 || $0 == 0 })
    }
    func testUInt16Arbitrary_forAllSimpleProperty() async {
        let result = await forAll("UInt16: n == n", { (n: UInt16) in XCTAssertEqual(n, n) }, UInt16.self)
        if case .falsified(let v, let e, _, _) = result { XCTFail("Prop failed for UInt16: \(v), err: \(e)")}
    }

    // --- Int32 ---
    func testInt32Arbitrary_gen() {
        var rng = newRng()
        let gen = Int32.gen
        var values = Set<Int32>()
        for _ in 0..<100 { // Less iterations for larger types is fine
            values.insert(gen.run(using: &rng))
        }
        XCTAssertGreaterThan(values.count, 1)
    }
    func testInt32Arbitrary_shrinker() {
        let shrinker = Int32.shrinker
        XCTAssertTrue(shrinker.shrink(0).isEmpty)
        XCTAssertTrue(shrinker.shrink(1).contains(0))
        let shrunkPositive = shrinker.shrink(50000)
        XCTAssertTrue(shrunkPositive.contains(0) && shrunkPositive.allSatisfy { abs($0) < 50000 || $0 == 0 })
    }
    func testInt32Arbitrary_forAllSimpleProperty() async {
        let result = await forAll("Int32: n == n", { (n: Int32) in XCTAssertEqual(n, n) }, Int32.self)
        if case .falsified(let v, let e, _, _) = result { XCTFail("Prop failed for Int32: \(v), err: \(e)")}
    }

    // --- UInt32 ---
    func testUInt32Arbitrary_gen() {
        var rng = newRng()
        let gen = UInt32.gen
        var values = Set<UInt32>()
        for _ in 0..<100 {
            values.insert(gen.run(using: &rng))
        }
        XCTAssertGreaterThan(values.count, 1)
    }
    func testUInt32Arbitrary_shrinker() {
        let shrinker = UInt32.shrinker
        XCTAssertTrue(shrinker.shrink(0).isEmpty)
        XCTAssertTrue(shrinker.shrink(1).contains(0))
        let shrunkPositive = shrinker.shrink(100000)
        XCTAssertTrue(shrunkPositive.contains(0) && shrunkPositive.allSatisfy { $0 < 100000 || $0 == 0 })
    }
    func testUInt32Arbitrary_forAllSimpleProperty() async {
        let result = await forAll("UInt32: n == n", { (n: UInt32) in XCTAssertEqual(n, n) }, UInt32.self)
        if case .falsified(let v, let e, _, _) = result { XCTFail("Prop failed for UInt32: \(v), err: \(e)")}
    }

    // MARK: - CGFloat Arbitrary Tests (Condensed)
    #if canImport(CoreGraphics) || canImport(Foundation)
    func testCGFloatArbitrary_gen(){var r=newRng();let g=CGFloat.gen;var dV=Set<CGFloat>();for _ in 0..<100{dV.insert(g.run(using:&r))};XCTAssertGreaterThan(dV.count,1);XCTAssertTrue(dV.allSatisfy{$0 >= -100.0 && $0 <= 100.0})}
    func testCGFloatArbitrary_shrinker(){let s=CGFloat.shrinker;XCTAssertTrue(s.shrink(0.0).isEmpty);XCTAssertTrue(s.shrink(1.0).contains(0.0));let sV=s.shrink(CGFloat(25.75));XCTAssertTrue(sV.contains(0.0));XCTAssertTrue(sV.allSatisfy{abs($0)<25.75||$0==0.0})}
    func testCGFloatArbitrary_forAllSimpleProperty()async{let r=await forAll("CGFloat:n==n",{(n:CGFloat)in XCTAssertEqual(n,n)},CGFloat.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}
    #endif

    // MARK: - Decimal Arbitrary Tests (Condensed)
    func testDecimalArbitrary_gen(){var r=newRng();let g=Decimal.gen;var dV=Set<Decimal>();for _ in 0..<100{dV.insert(g.run(using:&r))};XCTAssertGreaterThan(dV.count,1);for v in dV{XCTAssertTrue(v>=Decimal(-10001)&&v<=Decimal(10001))}}
    func testDecimalArbitrary_shrinker(){let s=Decimal.shrinker;XCTAssertTrue(s.shrink(Decimal.zero).isEmpty);XCTAssertTrue(s.shrink(Decimal(1)).contains(Decimal.zero));let v=Decimal(string:"123.45")!;let sV=s.shrink(v);XCTAssertFalse(sV.isEmpty);XCTAssertTrue(sV.contains(Decimal.zero));XCTAssertTrue(sV.contains(Decimal(123))||sV.contains(where:{$0.isInteger && $0 != v}))}
    func testDecimalArbitrary_forAllSimpleProperty()async{let r=await forAll("Decimal:n==n",{(n:Decimal)in XCTAssertEqual(n,n)},Decimal.self);if case .falsified(let v,let e,_,_)=r{XCTFail("P:\(v) E:\(e)")}}

    // MARK: - Character Arbitrary Tests (NEW)
    func testCharacterArbitrary_gen() {
        var rng = newRng()
        let gen = Character.gen
        var distinctValues = Set<Character>()
        var (letters, numbers, whitespaces, punctuations) = (0,0,0,0)
        for _ in 0..<200 {
            let char = gen.run(using: &rng)
            distinctValues.insert(char)
            if char.isLetter { letters += 1 }
            else if char.isNumber { numbers += 1 }
            else if char.isWhitespace { whitespaces += 1 }
            else if char.isPunctuation { punctuations += 1 }
        }
        XCTAssertGreaterThan(distinctValues.count, 10, "Character.gen should produce varied values.")
        XCTAssertGreaterThan(letters, 0, "Should generate letters")
        XCTAssertGreaterThan(numbers, 0, "Should generate numbers")
        XCTAssertGreaterThan(whitespaces, 0, "Should generate whitespaces/newlines")
        XCTAssertGreaterThan(punctuations, 0, "Should generate punctuations")
    }

    func testCharacterArbitrary_shrinker() {
        let shrinker = Character.shrinker
        // Access CharacterShrinker's simpleChars via the test helper extension
        let charShrinkerInstance = CharacterShrinker()
        let internalSimpleChars = charShrinkerInstance.simpleCharsForTesting

        let testSimpleChars: [Character] = ["c", "B", "5", "\t"]
        for simpleChar in testSimpleChars {
            guard let simpleScalarValue = simpleChar.unicodeScalars.first?.value else {
                XCTFail("Test setup error: simpleChar '\(simpleChar)' has no scalar value."); continue
            }
            if simpleScalarValue != 0 {
                 let shrunk = shrinker.shrink(simpleChar)
                 XCTAssertTrue(shrunk.allSatisfy { shrunkCandidate in
                    guard let shrunkScalarValue = shrunkCandidate.unicodeScalars.first?.value else { return false }
                    // Check if simpler in the internal list OR has a smaller unicode value
                    let isSimplerInList = internalSimpleChars.firstIndex(of: shrunkCandidate).map { $0 < (internalSimpleChars.firstIndex(of: simpleChar) ?? Int.max) } ?? false
                    return isSimplerInList || (shrunkScalarValue < simpleScalarValue)
                }, "Shrinking a simple char '\(simpleChar)' should produce simpler chars. Got: \(shrunk.map { String($0) })")
            }
        }
        
        let complexChar: Character = "Ö"
        let shrunkComplex = shrinker.shrink(complexChar)
        XCTAssertFalse(shrunkComplex.isEmpty, "Shrinking 'Ö' should produce results.")
        XCTAssertTrue(shrunkComplex.contains("O") || shrunkComplex.contains("o") || shrunkComplex.contains("a"), "Should try to simplify 'Ö'. Got: \(shrunkComplex.map { String($0) })")
        
        let shrunkA = shrinker.shrink("a")
        if let indexOfAInInternalList = internalSimpleChars.firstIndex(of: "a") {
            XCTAssertTrue(shrunkA.allSatisfy {
                (internalSimpleChars.firstIndex(of: $0) ?? Int.max) < indexOfAInInternalList
            }, "Shrinking 'a' should produce chars simpler than 'a' from the predefined list. Got: \(shrunkA.map { String($0) })")
        } else {
            XCTFail("'a' should be in the CharacterShrinker's simpleCharsForTesting for this test to be meaningful.")
        }
    }

    func testCharacterArbitrary_forAllSimpleProperty() async {
        let result = await forAll("Character: c == c", { (c: Character) in
            XCTAssertEqual(c, c)
        }, Character.self)
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'Character: c == c' should not have failed. Got '\(value)', error: \(error)")
        }
    }

    // MARK: - Unicode.Scalar Arbitrary Tests (NEW)
    func testUnicodeScalarArbitrary_gen() {
        var rng = newRng()
        let gen = Unicode.Scalar.gen
        var distinctValues = Set<Unicode.Scalar>()
        var asciiCount = 0
        for _ in 0..<100 {
            let scalar = gen.run(using: &rng)
            distinctValues.insert(scalar)
            if scalar.isASCII { asciiCount += 1}
        }
        XCTAssertGreaterThan(distinctValues.count, 5, "Unicode.Scalar.gen should produce varied values.")
        XCTAssertGreaterThan(asciiCount, 0, "Should generate some ASCII scalars")
    }

    func testUnicodeScalarArbitrary_shrinker() {
        let shrinker = Unicode.Scalar.shrinker
        let nullScalar = Unicode.Scalar(0)!
        XCTAssertTrue(shrinker.shrink(nullScalar).isEmpty, "Shrinking null scalar should be empty.")

        let capitalA_Scalar = Unicode.Scalar(65)! // "A"
        let shrunkA = shrinker.shrink(capitalA_Scalar)
        XCTAssertFalse(shrunkA.isEmpty)
        XCTAssertTrue(shrunkA.contains(nullScalar))
        let spaceScalar = Unicode.Scalar(32)!     // Space
        XCTAssertTrue(shrunkA.contains(spaceScalar), "Shrinking 'A' should offer space.")
        XCTAssertTrue(shrunkA.allSatisfy { $0.value < capitalA_Scalar.value })

        let omega_Scalar = Unicode.Scalar(0x03A9)! // Greek Omega Ω
        let shrunkOmega = shrinker.shrink(omega_Scalar)
        XCTAssertFalse(shrunkOmega.isEmpty)
        XCTAssertTrue(shrunkOmega.contains(nullScalar))
        let a_Scalar = Unicode.Scalar(97)!         // 'a'
        XCTAssertTrue(shrunkOmega.contains(a_Scalar), "Shrinking Omega should offer 'a'.")
    }

    func testUnicodeScalarArbitrary_forAllSimpleProperty() async {
        let result = await forAll("Unicode.Scalar: s == s", { (s: Unicode.Scalar) in
            XCTAssertEqual(s, s)
        }, Unicode.Scalar.self)
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'Unicode.Scalar: s == s' should not have failed. Got \(value) (value: \(value.value)), error: \(error)")
        }
    }
    
    // MARK: - UUID Arbitrary Tests (NEW)
    func testUUIDArbitrary_gen() {
        var rng = newRng() 
        let gen = UUID.gen
        var distinctValues = Set<UUID>()
        for _ in 0..<100 {
            distinctValues.insert(gen.run(using: &rng))
        }
        XCTAssertGreaterThanOrEqual(distinctValues.count, 95)
    }

    func testUUIDArbitrary_shrinker() {
        let shrinker = UUID.shrinker // This is `any Shrinker<UUID>`
        let randomUUID = UUID()
        let nilUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        let shrunkRandom = shrinker.shrink(randomUUID)
        if randomUUID != nilUUID {
            XCTAssertTrue(shrunkRandom.contains(nilUUID), "Shrinking a random UUID should offer the nil UUID. Got: \(shrunkRandom)")
            // Access UUIDShrinker's simpleUUIDs via the test helper extension
            let uuidShrinkerInstance = UUIDShrinker()
            XCTAssertTrue(shrunkRandom.count >= 1 && shrunkRandom.count <= uuidShrinkerInstance.simpleUUIDsForTesting.count)
        } else {
            XCTAssertTrue(shrunkRandom.isEmpty, "Shrinking the nil UUID should produce nothing.")
        }
        
        XCTAssertTrue(shrinker.shrink(nilUUID).isEmpty, "Shrinking the nil UUID should produce nothing.")
    }

    func testUUIDArbitrary_forAllSimpleProperty() async {
        let result = await forAll("UUID: u == u", { (u: UUID) in
            XCTAssertEqual(u, u)
        }, UUID.self)
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'UUID: u == u' should not have failed. Got \(value), error: \(error)")
        }
    }
}

// Helper extensions for testing internal details of shrinkers
// These should be fileprivate to ArbitraryTests.swift
fileprivate extension CharacterShrinker {
    var simpleCharsForTesting: [Character] { self.simpleChars }
}

fileprivate extension UUIDShrinker {
    var simpleUUIDsForTesting: [UUID] { self.simpleUUIDs }
}

// Remove this if defined elsewhere (e.g., RunnerTests.swift or a shared TestHelpers.swift)
// extension Array where Element: Hashable {
//     func removingDuplicates() -> [Element] {
//         var seen = Set<Element>()
//         return filter { seen.insert($0).inserted }
//     }
// }
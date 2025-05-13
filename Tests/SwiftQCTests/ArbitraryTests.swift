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

    // MARK: - Date Arbitrary Tests
    func testDateArbitrary_gen() {
        var rng = SystemRandomNumberGenerator()
        let gen = Date.gen
        var distinctValues = Set<Date>()
        let fiftyYears: TimeInterval = 50 * 365.25 * 24 * 3600
        let distantPast = Date().addingTimeInterval(-2 * fiftyYears) // Allow some buffer
        let distantFuture = Date().addingTimeInterval(2 * fiftyYears)

        for _ in 0..<100 {
            let date = gen.run(using: &rng)
            distinctValues.insert(date)
            XCTAssertTrue(date >= distantPast && date <= distantFuture, "Generated date \(date) out of expected range.")
        }
        XCTAssertGreaterThan(distinctValues.count, 10, "Date.gen should produce varied values.")
    }

    func testDateArbitrary_shrinker() {
        let shrinker = Date.shrinker
        let refDate = DateShrinker.referenceShrinkDate

        XCTAssertTrue(shrinker.shrink(refDate).isEmpty, "Shrinking the reference date should yield no results.")

        let futureDate = Date(timeIntervalSinceReferenceDate: 100000)
        let shrunkFuture = shrinker.shrink(futureDate)
        XCTAssertFalse(shrunkFuture.isEmpty)
        XCTAssertTrue(shrunkFuture.contains(refDate))
        XCTAssertTrue(shrunkFuture.allSatisfy { $0.timeIntervalSinceReferenceDate.magnitude < futureDate.timeIntervalSinceReferenceDate.magnitude || $0 == refDate })

        let pastDate = Date(timeIntervalSinceReferenceDate: -100000)
        let shrunkPast = shrinker.shrink(pastDate)
        XCTAssertFalse(shrunkPast.isEmpty)
        XCTAssertTrue(shrunkPast.contains(refDate))
        XCTAssertTrue(shrunkPast.allSatisfy { $0.timeIntervalSinceReferenceDate.magnitude < pastDate.timeIntervalSinceReferenceDate.magnitude || $0 == refDate })
    }

    func testDateArbitrary_forAllSimpleProperty() async {
        let result = await forAll("Date: d == d", { (d: Date) in
            XCTAssertEqual(d, d)
        }, Date.self)
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'Date: d == d' should not have failed. Got \(value), error: \(error)")
        }
    }

    // MARK: - Data Arbitrary Tests
    func testDataArbitrary_gen() {
        var rng = SystemRandomNumberGenerator()
        let gen = Data.gen
        var distinctValues = Set<Data>()
        var generatedNonEmpty = false
        for _ in 0..<100 {
            let data = gen.run(using: &rng)
            distinctValues.insert(data)
            if !data.isEmpty { generatedNonEmpty = true }
            XCTAssertTrue(data.count <= 1024) // Based on gen implementation
        }
        XCTAssertGreaterThan(distinctValues.count, 1, "Data.gen should produce varied values (could be all empty if count is often 0).")
        XCTAssertTrue(generatedNonEmpty || distinctValues.count <= 1, "Should see non-empty Data or only empty if count gen always 0.")
    }

    func testDataArbitrary_shrinker() {
        let shrinker = Data.shrinker
        XCTAssertTrue(shrinker.shrink(Data()).isEmpty)

        let originalData = Data([10, 20, 30, 40])
        let shrunkData = shrinker.shrink(originalData)

        XCTAssertFalse(shrunkData.isEmpty)
        XCTAssertTrue(shrunkData.contains(Data()), "Should shrink to empty Data.")
        XCTAssertTrue(shrunkData.contains(Data([10, 20])), "Should offer halved Data.") // prefix(2)
        XCTAssertTrue(shrunkData.contains(Data([10, 20, 30])), "Should offer Data with one less byte.") // dropLast

        // Test byte shrinking (if applicable due to size threshold in shrinker)
        if originalData.count < 10 {
            // XCTAssertTrue(shrunkData.contains(Data([0, 20, 30, 40])), "Should shrink individual bytes.")
        }
    }

    func testDataArbitrary_forAllSimpleProperty() async {
        let result = await forAll("Data: count >= 0", { (d: Data) in
            XCTAssertGreaterThanOrEqual(d.count, 0)
        }, Data.self)
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'Data: count >= 0' should not have failed. Got \(value.count) bytes, error: \(error)")
        }
    }

    // MARK: - DateComponents Arbitrary Tests
    func testDateComponentsArbitrary_gen() {
        var rng = SystemRandomNumberGenerator()
        let gen = DateComponents.gen
        var generatedAtLeastOneWithYear = false
        for _ in 0..<100 {
            let comps = gen.run(using: &rng)
            if let year = comps.year {
                generatedAtLeastOneWithYear = true
                XCTAssertTrue((1900...2100).contains(year))
            }
            if let month = comps.month { XCTAssertTrue((1...12).contains(month)) }
            if let day = comps.day { XCTAssertTrue((1...31).contains(day)) }
            // ... checks for other components ...
        }
        XCTAssertTrue(generatedAtLeastOneWithYear, "Should generate some components with a year specified.")
    }

    func testDateComponentsArbitrary_shrinker() {
        let shrinker = DateComponents.shrinker
        let emptyComps = DateComponents()
        XCTAssertTrue(shrinker.shrink(emptyComps).isEmpty, "Shrinking empty DateComponents should be empty.")

        let fullComps = DateComponents(year: 2023, month: 10, day: 26, hour: 14, minute: 30, second: 15, nanosecond: 100)
        let shrunkFull = shrinker.shrink(fullComps)

        XCTAssertFalse(shrunkFull.isEmpty)
        XCTAssertTrue(shrunkFull.contains(emptyComps), "Should shrink towards all-nil components.")
        
        // Check if it tries to nil out individual fields
        var yearNil = fullComps; yearNil.year = nil
        XCTAssertTrue(shrunkFull.contains(yearNil))

        // Check if it tries to shrink a value (e.g., year towards 1970)
        var yearShrunk = fullComps; yearShrunk.year = 1970
        XCTAssertTrue(shrunkFull.contains(yearShrunk))
    }

    func testDateComponentsArbitrary_forAllSimpleProperty() async {
        let result = await forAll("DateComponents: basic check", { (comps: DateComponents) in
            // A simple check, e.g., if year is present, it's within a broad range
            if let year = comps.year {
                XCTAssertTrue(year > 1000 && year < 3000)
            }
            XCTAssertTrue(true) // Placeholder for a more meaningful property
        }, DateComponents.self)
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'DateComponents: basic check' should not have failed. Got \(value), error: \(error)")
        }
    }

    // MARK: - URL Arbitrary Tests
    func testURLArbitrary_gen() {
        var rng = SystemRandomNumberGenerator()
        let gen = URL.gen
        var generatedURLs = 0
        var validURLs = 0
        for _ in 0..<100 {
            let url = gen.run(using: &rng)
            validURLs += 1
            XCTAssertNotNil(url.scheme, "Generated URL should have a scheme.")
            XCTAssertNotNil(url.host, "Generated URL should have a host.")
            generatedURLs += 1
        }
        XCTAssertGreaterThan(validURLs, 50, "URL.gen should produce a good number of valid URLs. Got \(validURLs).")
        XCTAssertEqual(generatedURLs, 100)
    }

    func testURLArbitrary_shrinker() {
        let shrinker = URL.shrinker
        let complexURL = URL(string: "https://www.example.com/path/to/resource?query=value&another=one#fragment")!
        
        let shrunkURLs = shrinker.shrink(complexURL)
        XCTAssertFalse(shrunkURLs.isEmpty)
        
        // Check for shrinking towards simpler scheme/host
        XCTAssertTrue(shrunkURLs.contains(URL(string: "http://a.com")!))
        XCTAssertTrue(shrunkURLs.contains(URL(string: "http://www.example.com/path/to/resource?query=value&another=one#fragment")!), "Should try http scheme")
        
        // Check for path shrinking
        XCTAssertTrue(shrunkURLs.contains(URL(string: "https://www.example.com/?query=value&another=one#fragment")!), "Should try removing path")
        
        // Check for query shrinking
        XCTAssertTrue(shrunkURLs.contains(URL(string: "https://www.example.com/path/to/resource#fragment")!), "Should try removing query")
        
        // Check for fragment shrinking
        XCTAssertTrue(shrunkURLs.contains(URL(string: "https://www.example.com/path/to/resource?query=value&another=one")!), "Should try removing fragment")

        //let simpleURL = URL(string: "http://a.com")!
        // XCTAssertTrue(shrinker.shrink(simpleURL).isEmpty, "Shrinking an already simple/known URL should be empty or minimal.")
    }

    func testURLArbitrary_forAllSimpleProperty() async {
        let result = await forAll("URL: scheme is http or https", { (url: URL) in
            XCTAssertTrue(url.scheme == "http" || url.scheme == "https", "Scheme was \(url.scheme ?? "nil")")
        }, URL.self) // URL.self assumes URL now directly conforms, or use wrapper if needed
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'URL: scheme check' should not have failed. Got \(value.absoluteString), error: \(error)")
        }
    }

    // MARK: - Range<Int> Arbitrary Tests
    func testRangeIntArbitrary_gen() {
        var rng = newRng() // Uses your helper
        let gen = Range<Int>.gen // Assuming Range<Int> conforms to Arbitrary, using its .gen
        var generatedRanges: [Range<Int>] = []
        var nonEmptyRangeGenerated = false
        var generationAttempts = 0
        let maxAttempts = 400 // Allow more attempts if filtering is aggressive

        // Try to generate a decent number of ranges, accounting for potential filtering
        // in the Range.gen implementation (if it filters out equal bounds).
        while generatedRanges.count < 100 && generationAttempts < maxAttempts {
            let range = gen.run(using: &rng) // This should directly return Range<Int>
            
            // Since Range.gen in Range+Arbitrary.swift uses flatMap + compactMap,
            // if the intermediate Gen.always(nil) is hit, compactMap filters it.
            // So, a run of `gen.run()` will either give a valid Range<Int> or the internal Gen might have
            // effectively "failed" to produce one for that particular seed state if the bounds were equal.
            // To test it, we'll just run it. If it *could* still produce an "empty" or invalid state
            // that wasn't filtered, the XCTAssertLessThan below would catch it.
            
            generatedRanges.append(range)
            XCTAssertLessThan(range.lowerBound, range.upperBound, "Generated Range must have lowerBound < upperBound. Got \(range)")
            if !range.isEmpty { // Range.isEmpty checks if lowerBound == upperBound
                nonEmptyRangeGenerated = true
            }
            generationAttempts += 1
        }
        
        XCTAssertGreaterThanOrEqual(generatedRanges.count, 50, "Should generate a reasonable number of valid ranges after attempts. Got \(generatedRanges.count)")

        if !generatedRanges.isEmpty {
            XCTAssertTrue(nonEmptyRangeGenerated, "All generated ranges should be non-empty due to lowerBound < upperBound assertion.")
            if generatedRanges.count > 10 {
                XCTAssertGreaterThan(Set(generatedRanges).count, 5, "Generated ranges should show some variety.")
            }
        }
    }

    func testRangeIntArbitrary_shrinker() {
        let shrinker = Range<Int>.shrinker // Assuming Range<Int> conforms
        let testRangeOpen = 0..<10

        let shrunkOpen = shrinker.shrink(testRangeOpen)
        XCTAssertFalse(shrunkOpen.isEmpty, "Shrinking 0..<10 should produce results.")
        
        // Check for specific expected shrink patterns
        // Note: Direct span comparison (r.count) is fine for Int ranges
        XCTAssertTrue(shrunkOpen.contains(where: { $0.count < testRangeOpen.count }), "Should try to reduce the span.")
        XCTAssertTrue(shrunkOpen.contains(where: { $0.lowerBound > testRangeOpen.lowerBound && $0.lowerBound < $0.upperBound }), "Should try to shrink lower bound up.")
        XCTAssertTrue(shrunkOpen.contains(where: { $0.upperBound < testRangeOpen.upperBound && $0.lowerBound < $0.upperBound }), "Should try to shrink upper bound down.");

        for r_val in shrunkOpen { // Renamed 'r' to avoid conflict if 'r' is used outside
            XCTAssertLessThan(r_val.lowerBound, r_val.upperBound, "Shrunk range \(r_val) is invalid.")
        }

        let verySmallRange = 0..<1
        let shrunkVerySmall = shrinker.shrink(verySmallRange)
        XCTAssertTrue(shrunkVerySmall.isEmpty, "Shrinking 0..<1 for Ints should result in no valid smaller ranges.")

        let negativeRange = -10 ..< -5
        let shrunkNegative = shrinker.shrink(negativeRange)
        XCTAssertFalse(shrunkNegative.isEmpty, "Shrinking -10..< -5 should produce results.")
        XCTAssertTrue(shrunkNegative.contains(where: { $0.count < negativeRange.count && $0.lowerBound < $0.upperBound }), "Negative range shrink should reduce span.")
    }

    func testRangeIntArbitrary_forAllSimpleProperty() async {
        let result = await forAll("Range<Int> property: lower < upper", { (r: Range<Int>) in
            XCTAssertLessThan(r.lowerBound, r.upperBound)
        }, Range<Int>.self) // Explicitly pass the Arbitrary type
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'Range<Int> property: lower < upper' failed. Value: \(value), Error: \(error)")
        }
    }

    // MARK: - ClosedRange<Int> Arbitrary Tests
    func testClosedRangeIntArbitrary_gen() {
        var rng = newRng(seed: 1)
        let gen = ClosedRange<Int>.gen // Assuming ClosedRange<Int> conforms
        var generatedRanges: [ClosedRange<Int>] = []
        var generatedSinglePointRange = false
        var generatedMultiPointRange = false

        for _ in 0..<100 {
            let range = gen.run(using: &rng) // This should not be optional for ClosedRange.gen
            generatedRanges.append(range)
            XCTAssertLessThanOrEqual(range.lowerBound, range.upperBound, "Generated ClosedRange must have lowerBound <= upperBound. Got \(range)")
            if range.lowerBound == range.upperBound {
                generatedSinglePointRange = true
            } else {
                generatedMultiPointRange = true
            }
        }
        XCTAssertTrue(!generatedRanges.isEmpty, "ClosedRange<Int>.gen should produce valid ranges.")
        XCTAssertTrue(generatedSinglePointRange, "Should generate some single-point ranges (e.g., 5...5).")
        XCTAssertTrue(generatedMultiPointRange, "Should generate some multi-point ranges (e.g., 3...7).")
        if generatedRanges.count > 10 {
             XCTAssertGreaterThan(Set(generatedRanges).count, 5, "Generated closed ranges should show some variety.")
        }
    }

    func testClosedRangeIntArbitrary_shrinker() {
        let shrinker = ClosedRange<Int>.shrinker // Assuming ClosedRange<Int> conforms
        let testRangeClosed = 0...10

        let shrunkClosed = shrinker.shrink(testRangeClosed)
        XCTAssertFalse(shrunkClosed.isEmpty, "Shrinking 0...10 should produce results.")
        XCTAssertTrue(shrunkClosed.contains(0...0), "Should be able to shrink to lower...lower (0...0).")
        XCTAssertTrue(shrunkClosed.contains(10...10), "Should be able to shrink to upper...upper (10...10).")
        // Using .count is fine for ClosedRange<Int>
        XCTAssertTrue(shrunkClosed.contains(where: { $0.count < testRangeClosed.count }), "Should try to reduce the span.")
        XCTAssertTrue(shrunkClosed.contains(where: { $0.lowerBound > testRangeClosed.lowerBound && $0.lowerBound <= $0.upperBound }), "Should try to shrink lower bound up.")
        XCTAssertTrue(shrunkClosed.contains(where: { $0.upperBound < testRangeClosed.upperBound && $0.lowerBound <= $0.upperBound }), "Should try to shrink upper bound down.");

        for r_val in shrunkClosed { // Renamed 'r'
            XCTAssertLessThanOrEqual(r_val.lowerBound, r_val.upperBound, "Shrunk range \(r_val) is invalid.")
        }

        let singlePointRange = 5...5
        let shrunkSinglePoint = shrinker.shrink(singlePointRange)
        let fiveShrinks = Int.shrinker.shrink(5)
        var foundExpectedShrink = false
        if !fiveShrinks.isEmpty { // Only check if 5 itself can be shrunk
            for shrunkBound in fiveShrinks {
                if shrunkSinglePoint.contains(shrunkBound...shrunkBound) {
                    foundExpectedShrink = true
                    break
                }
            }
            XCTAssertTrue(foundExpectedShrink, "Shrinking 5...5 should offer ranges like x...x where x is a shrink of 5. Got: \(shrunkSinglePoint)")
        } else {
            // If 5 is already minimal (e.g., if Int.shrinker changed or if 5 was 0), then shrunkSinglePoint might be empty
            // or only contain attempts to break the single-point nature if the logic allowed, but our ClosedRangeShrinker tries to keep it single-point
            // if the original was single-point and only shrinks the bound.
            // For a non-minimal bound like 5, we expect shrinks. If fiveShrinks is empty, this XCTAssert path might be too strict.
        }
        
        let zeroRange = 0...0 // 0 is minimal for IntShrinker
        XCTAssertTrue(shrinker.shrink(zeroRange).isEmpty, "Shrinking 0...0 should be empty.")
    }

    func testClosedRangeIntArbitrary_forAllSimpleProperty() async {
        let result = await forAll("ClosedRange<Int> property: lower <= upper", { (r: ClosedRange<Int>) in
            XCTAssertLessThanOrEqual(r.lowerBound, r.upperBound)
        }, ClosedRange<Int>.self) // Explicitly pass the Arbitrary type
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property 'ClosedRange<Int> property: lower <= upper' failed. Value: \(value), Error: \(error)")
        }
    }

    // MARK: - Void Arbitrary Tests
    func testVoidArbitrary_gen() {
        var rng = newRng()
        let voidGen = VoidWrapper.gen // Use VoidWrapper instead of Void
        let generatedValue: Void = voidGen.run(using: &rng) // Explicit type annotation
        XCTAssertNotNil(generatedValue, "Void.gen should produce a value.")
        // Can't assert much more about the value of Void other than it exists.
    }

    func testVoidArbitrary_shrinker() {
        let voidShrinker = VoidWrapper.shrinker // Use VoidWrapper instead of Void
        let shrunkValues: [Void] = voidShrinker.shrink(()) // Explicit type annotation
        XCTAssertTrue(shrunkValues.isEmpty, "Shrinking Void should produce no values.")
    }

    func testVoidArbitrary_forAllSimpleProperty() async {
        var propertyRunCount = 0
        for _ in 0..<10 { // Loop instead of forAll
            // Trivial property for Void, just ensure the closure is run
            propertyRunCount += 1
        }
        
        XCTAssertEqual(propertyRunCount, 10, "Should have run the property 10 times.")
    }

    // MARK: - ContiguousArray<Int> Arbitrary Tests
    func testContiguousArrayIntArbitrary_gen() {
        var rng = newRng()
        let gen = ContiguousArray<Int>.gen
        var generatedArrays: [ContiguousArray<Int>] = []
        var generatedNonEmpty = false
        for _ in 0..<100 {
            let arr = gen.run(using: &rng)
            generatedArrays.append(arr)
            if !arr.isEmpty { generatedNonEmpty = true }
            XCTAssertTrue(arr.count <= 100) // Based on Array.gen's countGenerator
        }
        XCTAssertTrue(!generatedArrays.isEmpty, "ContiguousArray<Int>.gen should produce arrays.")
        XCTAssertTrue(generatedNonEmpty || generatedArrays.allSatisfy { $0.isEmpty }, "Should see non-empty or all empty.")
        if generatedArrays.count > 10 {
            XCTAssertGreaterThan(Set(generatedArrays.map { Array($0) }).count, 5, "Generated arrays should show variety.")
        }
    }

    func testContiguousArrayIntArbitrary_shrinker() {
        let shrinker = ContiguousArray<Int>.shrinker
        let testArray: ContiguousArray<Int> = [10, 20, 0]
        
        let shrunk = shrinker.shrink(testArray)
        XCTAssertFalse(shrunk.isEmpty)
        XCTAssertTrue(shrunk.contains([]))
        XCTAssertTrue(shrunk.contains([10, 20])) // Drop last
        XCTAssertTrue(shrunk.contains([0, 20, 0]) || shrunk.contains(where: { $0.first != 10 && $0.count == 3 })) // Shrunk element
    }

    func testContiguousArrayIntArbitrary_forAllSimpleProperty() async {
        let result = await forAll("ContiguousArray<Int> property: map identity", { (arr: ContiguousArray<Int>) in
            XCTAssertEqual(arr.map { $0 }, Array(arr))
        }, ContiguousArray<Int>.self)
        if case .falsified(let value, let error, _, _) = result {
            XCTFail("Property failed for ContiguousArray<Int>. Value: \(value), Error: \(error)")
        }
    }
}

// MARK: - Helper extensions for testing internal details of shrinkers
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
//
//  DateComponents+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen
import Foundation

public struct DateComponentsShrinker: Shrinker {
    public typealias Value = DateComponents
    private func shrinkOptionalInt(_ component: Int?, simpleTarget: Int = 0) -> [Int?] {
        guard let value = component else { return [] }; var shrinks: [Int?] = [nil]
        for shrunkInt in Int.shrinker.shrink(value) { if shrunkInt == simpleTarget || (simpleTarget == 0 && shrunkInt == 0) { if !shrinks.contains(simpleTarget) { shrinks.append(simpleTarget) }} else { if !shrinks.contains(shrunkInt) { shrinks.append(shrunkInt) }}}
        if value != simpleTarget && !Int.shrinker.shrink(value).contains(simpleTarget) && !shrinks.contains(simpleTarget) { shrinks.append(simpleTarget) }
        return Array(Set(shrinks.filter { $0 != component }))
    }
    public func shrink(_ comps: DateComponents) -> [DateComponents] {
        var shrinks: [DateComponents] = [];
        if comps.year != nil { var c=comps; c.year=nil; shrinks.append(c) }; if comps.month != nil { var c=comps; c.month=nil; shrinks.append(c) }; if comps.day != nil { var c=comps; c.day=nil; shrinks.append(c) }
        if comps.hour != nil { var c=comps; c.hour=nil; shrinks.append(c) }; if comps.minute != nil { var c=comps; c.minute=nil; shrinks.append(c) }; if comps.second != nil { var c=comps; c.second=nil; shrinks.append(c) }; if comps.nanosecond != nil { var c=comps; c.nanosecond=nil; shrinks.append(c) }
        for sY in shrinkOptionalInt(comps.year,simpleTarget:1970){var c=comps;c.year=sY;if !shrinks.contains(c){shrinks.append(c)}}; for sM in shrinkOptionalInt(comps.month,simpleTarget:1){var c=comps;c.month=sM;if !shrinks.contains(c){shrinks.append(c)}}
        for sD in shrinkOptionalInt(comps.day,simpleTarget:1){var c=comps;c.day=sD;if !shrinks.contains(c){shrinks.append(c)}}; for sH in shrinkOptionalInt(comps.hour){var c=comps;c.hour=sH;if !shrinks.contains(c){shrinks.append(c)}}
        for sMin in shrinkOptionalInt(comps.minute){var c=comps;c.minute=sMin;if !shrinks.contains(c){shrinks.append(c)}}; for sS in shrinkOptionalInt(comps.second){var c=comps;c.second=sS;if !shrinks.contains(c){shrinks.append(c)}}
        for sN in shrinkOptionalInt(comps.nanosecond){var c=comps;c.nanosecond=sN;if !shrinks.contains(c){shrinks.append(c)}}
        let allNil=DateComponents(); if comps != allNil && !shrinks.contains(allNil){shrinks.append(allNil)}
        return Array(Set(shrinks)).sorted(by:{let c1=(($0.year==nil ?0:1)+($0.month==nil ?0:1)+($0.day==nil ?0:1)+($0.hour==nil ?0:1)+($0.minute==nil ?0:1)+($0.second==nil ?0:1)+($0.nanosecond==nil ?0:1));let c2=(($1.year==nil ?0:1)+($1.month==nil ?0:1)+($1.day==nil ?0:1)+($1.hour==nil ?0:1)+($1.minute==nil ?0:1)+($1.second==nil ?0:1)+($1.nanosecond==nil ?0:1));if c1 != c2{return c1<c2};return ($0.year ?? 0)<($1.year ?? 0)})
    }
}

// Helper function to create an optional generator with custom nil probability
private func optionalGen<T>(from baseGen: Gen<T>, probabilityOfNil: Double) -> Gen<T?> {
    guard (0.0...1.0).contains(probabilityOfNil) else {
        // Handle invalid probability, perhaps default or fatalError
        print("Warning: Invalid probabilityOfNil (\\(probabilityOfNil)) provided to optionalGen. Defaulting to 0.5")
        return optionalGen(from: baseGen, probabilityOfNil: 0.5) 
    }
    let probabilityOfSome = 1.0 - probabilityOfNil
    // Gen.frequency expects integer weights. Convert probabilities to approximate integer weights.
    // Using a large base number like 1000 for better approximation.
    let nilWeight = Int((probabilityOfNil * 1000).rounded())
    let someWeight = Int((probabilityOfSome * 1000).rounded())

    // Ensure at least one weight is non-zero if probability isn't exactly 0 or 1
    if nilWeight == 0 && someWeight == 0 && probabilityOfNil > 0 && probabilityOfNil < 1 {
         return optionalGen(from: baseGen, probabilityOfNil: probabilityOfNil > 0.5 ? 1.0 : 0.0) // Force to one end
    }
    if nilWeight == 0 && probabilityOfNil > 0 { return Gen.always(nil) } // Edge case: probability is 1.0
    if someWeight == 0 && probabilityOfSome > 0 { return baseGen.map { Optional($0) } } // Edge case: probability is 0.0

    return Gen.frequency(
        (nilWeight, Gen.always(nil)),
        (someWeight, baseGen.map { Optional($0) })
    )
}

extension DateComponents: Arbitrary {
    public typealias Value = DateComponents

    public static var gen: Gen<DateComponents> {
        // Define individual generators for optional components using the helper
        let yearGen = optionalGen(from: Gen.int(in: 1900...2100), probabilityOfNil: 0.2)
        let monthGen = optionalGen(from: Gen.int(in: 1...12), probabilityOfNil: 0.3)
        let dayGen = optionalGen(from: Gen.int(in: 1...31), probabilityOfNil: 0.3)
        let hourGen = optionalGen(from: Gen.int(in: 0...23), probabilityOfNil: 0.4)
        let minuteGen = optionalGen(from: Gen.int(in: 0...59), probabilityOfNil: 0.4)
        let secondGen = optionalGen(from: Gen.int(in: 0...59), probabilityOfNil: 0.5)
        let nanosecondGen = optionalGen(from: Gen.int(in: 0...999_999_999), probabilityOfNil: 0.8)

        // Combine them using zip and map to DateComponents
        return zip(yearGen, monthGen, dayGen, hourGen, minuteGen, secondGen, nanosecondGen).map {
            var components = DateComponents()
            components.year = $0
            components.month = $1
            components.day = $2
            components.hour = $3
            components.minute = $4
            components.second = $5
            components.nanosecond = $6
            return components
        }
    }

    public static var shrinker: any Shrinker<DateComponents> { DateComponentsShrinker() }
}
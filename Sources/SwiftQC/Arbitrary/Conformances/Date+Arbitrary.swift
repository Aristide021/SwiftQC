//
//  Date+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen
import Foundation

public struct DateShrinker: Shrinker {
    public typealias Value = Date

    // Reference date for shrinking (e.g., start of the Unix epoch or referenceDate)
    public static let referenceShrinkDate = Date(timeIntervalSinceReferenceDate: 0) // Jan 1, 2001
    // public static let referenceShrinkDate = Date(timeIntervalSince1970: 0) // Or Unix epoch

    public func shrink(_ value: Date) -> [Date] {
        // Shrink the underlying TimeInterval
        let timeInterval = value.timeIntervalSinceReferenceDate
        guard timeInterval != 0 else { // Already at the reference date (or a common "zero" point)
            // If it's the reference date, no further shrinks unless we define other specific "simple" dates
            if value == Self.referenceShrinkDate {
                return []
            } else {
                // If it's some other date whose interval is 0 from *its* reference,
                // still offer our canonical reference date.
                return [Self.referenceShrinkDate].filter { $0 != value }
            }
        }

        var shrinks: [Date] = []
        
        // 1. Offer the reference date
        if value != Self.referenceShrinkDate {
            shrinks.append(Self.referenceShrinkDate)
        }

        // 2. Shrink timeInterval towards 0 (using Double's shrinker logic as a base)
        let doubleShrinker = Shrinkers.double // Use the existing DoubleShrinker
        let shrunkIntervals = doubleShrinker.shrink(timeInterval)

        for interval in shrunkIntervals {
            let newDate = Date(timeIntervalSinceReferenceDate: interval)
            if newDate != value && !shrinks.contains(newDate) { // Ensure different and not already added
                shrinks.append(newDate)
            }
        }
        
        // Sort dates chronologically for consistency
        return Array(Set(shrinks)).sorted()
    }
}

extension Date: Arbitrary {
    public typealias Value = Date

    public static var gen: Gen<Date> {
        // Generate a TimeInterval (Double) within a reasonable range around the present.
        // E.g., +/- 50 years from now. 50 years * 365.25 days/year * 24 h/day * 3600 s/h
        let fiftyYearsInSeconds: TimeInterval = 50 * 365.25 * 24 * 3600
        let now = Date().timeIntervalSinceReferenceDate
        
        // Use TimeInterval.arbitrary if available, otherwise Double.arbitrary
        // As TimeInterval is typealias for Double, Double.gen is appropriate
        return Gen.double(in: (now - fiftyYearsInSeconds)...(now + fiftyYearsInSeconds))
            .map { Date(timeIntervalSinceReferenceDate: $0) }
    }

    public static var shrinker: any Shrinker<Date> { DateShrinker() }
}
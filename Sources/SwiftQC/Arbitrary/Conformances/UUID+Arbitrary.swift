//
//  UUID+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen
import Foundation // For UUID

public struct UUIDShrinker: Shrinker {
    public typealias Value = UUID

    // A few "simpler" or well-known UUIDs to shrink towards.
    // The nil UUID (all zeros) is a common target.
    internal let simpleUUIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        // You could add other specific "simple" UUIDs if they make sense for your domain
        // e.g., UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    ]

    public func shrink(_ value: UUID) -> [UUID] {
        // If the UUID is already one of the simple ones, don't shrink further.
        if simpleUUIDs.contains(value) {
            return []
        }
        // Otherwise, offer the simple ones as candidates if they are different.
        return simpleUUIDs.filter { $0 != value }
    }
}

extension UUID: Arbitrary {
    public typealias Value = UUID

    public static var gen: Gen<UUID> {
        // Each run of the Gen produces a new, random UUID.
        Gen.always(()).map { _ in UUID() }
    }

    public static var shrinker: any Shrinker<UUID> { UUIDShrinker() }
}
//
//  Optional+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen // For Gen and its .optional property
// Ensure Arbitrary and Shrinker protocols are accessible from SwiftQC's core modules

// Define a specific shrinker for Optional values.
// This is kept fileprivate as it's an implementation detail for Optional's Arbitrary conformance.
fileprivate struct OptionalShrinker<WrappedValue>: Shrinker {
    // Removed Sendable constraint from WrappedValue as Arbitrary.Value doesn't guarantee it.
    // This shrinker operates synchronously and doesn't inherently require Sendable
    // for its current logic.

    typealias Value = WrappedValue?
    private let wrappedShrinker: any Shrinker<WrappedValue>

    init(wrappedShrinker: any Shrinker<WrappedValue>) {
        self.wrappedShrinker = wrappedShrinker
    }

    public func shrink(_ value: WrappedValue?) -> [WrappedValue?] {
        guard let unwrappedValue = value else {
            // If the value is already nil, it cannot be shrunk further.
            return []
        }

        // When shrinking an Optional.some(value):
        // 1. Offer `nil` as the "simplest" shrunk value.
        var shrinks: [WrappedValue?] = [nil]

        // 2. Offer shrunken versions of the wrapped value, still wrapped in .some.
        for shrunkWrappedValue in wrappedShrinker.shrink(unwrappedValue) {
            shrinks.append(WrappedValue?(shrunkWrappedValue)) // Or .some(shrunkWrappedValue)
        }
        return shrinks
    }
}

extension Optional: Arbitrary where Wrapped: Arbitrary {
    public typealias Value = Wrapped.Value?

    public static var gen: Gen<Wrapped.Value?> {
        return Wrapped.gen.optional
    }

    public static var shrinker: any Shrinker<Wrapped.Value?> {
        // Now instantiates OptionalShrinker without requiring Wrapped.Value to be Sendable.
        return OptionalShrinker<Wrapped.Value>(wrappedShrinker: Wrapped.shrinker)
    }
}
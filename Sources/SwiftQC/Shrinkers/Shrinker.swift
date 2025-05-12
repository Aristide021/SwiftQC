//
//  Shrinker.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

/// A type that produces "smaller" candidates for a given value.
///
/// - `Value`: The type of values this shrinker operates on. This is a primary associated type.
public protocol Shrinker<Value>: Sendable{
    /// The type of values this shrinker operates on.
    associatedtype Value
    /// Given a value, return an array of "smaller" candidates.
    func shrink(_ value: Value) -> [Value]
}

//
//  NoShrink.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

public struct NoShrink<T: Sendable>: Shrinker {
    public typealias Value = T
    public init() {}

    public func shrink(_ value: T) -> [T] {
        return []
    }
}
//
//  Bool+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//
import Gen

public struct BoolShrinker: Shrinker {
  public typealias Value = Bool
  public func shrink(_ value: Bool) -> [Bool] {
    value ? [false] : []
  }
}

extension Bool: Arbitrary {
  public typealias Value = Bool
  public static var gen: Gen<Bool> {
    Gen.bool
  }
  public static var shrinker: any Shrinker<Bool> {
    BoolShrinker()
  }
}

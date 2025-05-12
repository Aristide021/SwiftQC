//
//  Property.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen

/// A property test: a generator plus an async-throwing assertion.
public struct Property<Value> {
  public let gen: Gen<Value>
  public let test: (Value) async throws -> Void

  public init(
    gen: Gen<Value>,
    test: @escaping (Value) async throws -> Void
  ) {
    self.gen = gen
    self.test = test
  }
}

extension Property where Value: Arbitrary, Value.Value == Value {
  /// Use the default generator for `Value`.
  public init(
    _ name: String = "",
    test: @escaping (Value) async throws -> Void
  ) {
    self.init(gen: Value.gen, test: test)
  }
}

public enum Properties {
  /// Build a property from an explicit generator.
  public static func forAll<A>(
    _ gen: Gen<A>,
    _ name: String = "",
    file: StaticString = #file, line: UInt = #line,
    _ test: @escaping (A) async throws -> Void
  ) -> Property<A> {
    Property(gen: gen, test: test)
  }

  /// Build a property for an `Arbitrary` type.
  public static func forAll<A: Arbitrary>(
    _ name: String = "",
    file: StaticString = #file, line: UInt = #line,
    _ test: @escaping (A) async throws -> Void
  ) -> Property<A> where A.Value == A {
    Property(gen: A.gen, test: test)
  }
}

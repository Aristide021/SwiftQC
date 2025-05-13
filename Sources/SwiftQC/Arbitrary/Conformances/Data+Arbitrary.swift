//
//  Data+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen
import Foundation

public struct DataShrinker: Shrinker { // ... (Keep your existing DataShrinker logic) ...
    public typealias Value = Data
    public func shrink(_ value: Data) -> [Data] {
        let byteArray = [UInt8](value); guard !byteArray.isEmpty else { return [] }; var shrinks: [Data] = [Data()]
        if byteArray.count > 1 { shrinks.append(Data(byteArray.prefix(byteArray.count/2))) }
        shrinks.append(Data(byteArray.dropLast()))
        if byteArray.count < 10 { let byteShrinker = Shrinkers.uint8
            for i in byteArray.indices { let originalByte = byteArray[i]
                for shrunkByte in byteShrinker.shrink(originalByte) { var nBA = byteArray; nBA[i]=shrunkByte; shrinks.append(Data(nBA)) }
            }
        }
        return Array(Set(shrinks.filter { $0.count < value.count || $0.isEmpty })).sorted { $0.count < $1.count }
    }
}

extension Data: Arbitrary {
    public typealias Value = Data

    public static var gen: Gen<Data> {
        let byteCountGen = Gen.int(in: 0...1024)
        // To get Gen<UInt8>, use UInt8.gen assuming UInt8 conforms to Arbitrary
        // If UInt8 is not yet Arbitrary, you'd use Gen.uint8(in: .min ... .max)
        // Assuming UInt8 is now Arbitrary from FixedWidthInteger+Arbitrary.swift
        return UInt8.gen.array(of: byteCountGen).map { byteArray -> Data in
            return Data(byteArray) // Data([UInt8]) is a valid initializer
        }
    }

    public static var shrinker: any Shrinker<Data> { DataShrinker() }
}
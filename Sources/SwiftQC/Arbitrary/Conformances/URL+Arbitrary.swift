//
//  URL+ArbitraryTests.swift
//  SwiftQC
//
//  Created by Sheldon Aristide on 5/12/25.
//  Copyright (c) 2025 Sheldon Aristide. All rights reserved.
//

import Gen
import Foundation

public struct URLShrinker: Shrinker { // ... (Keep your existing URLShrinker logic) ...
    public typealias Value = URL
    private static let simpleSchemeHost = "http://a.com"
    private static let simpleURLs: [URL] = [
        URL(string: simpleSchemeHost)!,
        URL(string: "https://b.org")!
    ].compactMap { $0 }

    public func shrink(_ url: URL) -> [URL] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return Self.simpleURLs.filter { $0 != url }
        }
        var shrinks: [URL] = []
        for simple in Self.simpleURLs { if url != simple { shrinks.append(simple) } }
        if let scheme = components.scheme, scheme != "http" {
            var newComps = components; newComps.scheme = "http"
            if let newURL = newComps.url, newURL != url { shrinks.append(newURL) }
        }
        if let host = components.host {
            let simpleHosts = ["a.com", "b.org", "test.com"]
            for sh in simpleHosts {
                if host != sh { var nc = components; nc.host = sh; if let nu = nc.url, nu != url { shrinks.append(nu) }}
            }
            for shrunkHostComponent in String.shrinker.shrink(host) {
                 if !shrunkHostComponent.isEmpty && shrunkHostComponent.contains(".") { // Basic check
                    var nc = components; nc.host = shrunkHostComponent; if let nu = nc.url, nu != url { shrinks.append(nu) }
                }
            }
        }
        let pathComps = components.path.split(separator:"/").map(String.init).filter{!$0.isEmpty}
        if !pathComps.isEmpty {
            var nc1 = components; nc1.path = "/"; if let nu = nc1.url, nu != url { shrinks.append(nu) }
            if components.path != "" { var nc2 = components; nc2.path = ""; if let nu = nc2.url, nu != url && !shrinks.contains(nu) { shrinks.append(nu) }}
            if pathComps.count > 1 { var nc3 = components; nc3.path = "/" + pathComps.dropLast().joined(separator:"/"); if let nu = nc3.url, nu != url { shrinks.append(nu) }}
        }
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            var nc1 = components; nc1.queryItems = nil; if let nu = nc1.url, nu != url { shrinks.append(nu) }
            if queryItems.count > 0 { var nc2 = components; nc2.queryItems = Array(queryItems.dropLast()); if nc2.queryItems?.isEmpty ?? false {nc2.queryItems=nil}; if let nu = nc2.url, nu != url { shrinks.append(nu) }}
        }
        if components.fragment != nil { var nc = components; nc.fragment = nil; if let nu = nc.url, nu != url { shrinks.append(nu) }}
        return Array(Set(shrinks.filter { $0 != url })).sorted(by: { $0.absoluteString.count < $1.absoluteString.count })
    }
}

extension URL: Arbitrary {
    public typealias Value = URL

    // Define the Int generator as a static computed property for concurrency safety and accessibility
    internal static var sharedIntGenForDigits: Gen<Int> {
        Gen.int(in: 0...9)
    }

    // Helper to create an alphanumeric character generator
    private static func alphanumericCharGen() -> Gen<Character> {
        Gen.frequency(
            (26, Gen<Character>.letter),
            (26, Gen<Character>.letter.map { Character(String($0).uppercased()) }),
            (10, Gen.int(in: 0...9).map { Character("\($0)") }) // Use Gen.int directly
        )
    }

    public static var gen: Gen<URL> {
        let schemeGen = Gen.element(of: ["http", "https"])
        let hostNameGen = Self.alphanumericCharGen().string(of: Gen.int(in: 3...10))
        let hostGen = hostNameGen.map { "\($0).com" }

        let pathStringGen = Self.alphanumericCharGen().string(of: Gen.int(in: 0...10))
        let pathGen = pathStringGen.map { $0.isEmpty ? "" : "/\($0)" }
        
        return zip(schemeGen, hostGen, pathGen).map { (schemeOpt, host, path) in
             let scheme = schemeOpt ?? "http"
            let urlString = "\(scheme)://\(host)\(path)"
            return URL(string: urlString)!
        }
    }

    public static var shrinker: any Shrinker<URL> { URLShrinker() }
}

extension Gen where Value == Character {
    static var digit: Gen<Character> {
        // Reference the Int generator defined outside this extension
        return Gen.frequency(
            (10, URL.sharedIntGenForDigits.map { Character("\($0)") })
        )
    }
}
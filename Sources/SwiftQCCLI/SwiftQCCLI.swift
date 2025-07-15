import ArgumentParser
import SwiftQC
import Gen
import Foundation

// MARK: - Main CLI Structure

@main
struct SwiftQCCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftqc",
        abstract: "A command-line interface for SwiftQC property-based testing",
        version: "1.0.0",
        subcommands: [Run.self, Stateful.self, Interactive.self, Examples.self],
        defaultSubcommand: Run.self
    )
}

// MARK: - Missing ConsoleReporter Implementation

struct ConsoleReporter: Reporter {
    public func reportSuccess(description: String, iterations: Int) {
        print("✅ \(description): \(iterations) tests passed")
    }
    
    public func reportFailure<T>(description: String, input: T, error: Error, file: StaticString, line: UInt) {
        print("❌ \(description): Failed")
        print("   Input: \(input)")
        print("   Error: \(error)")
        print("   Location: \(file):\(line)")
    }
    
    public func reportShrinkProgress<T>(from: T, to: T) {
        print("🔍 Shrinking: \(from) → \(to)")
    }
    
    public func reportFinalCounterexample<T>(description: String, input: T, error: Error, file: StaticString, line: UInt) {
        print("🎯 FINAL COUNTEREXAMPLE for '\(description)':")
        print("   Minimal input: \(input)")
        print("   Error: \(error)")
        print("   Location: \(file):\(line)")
    }
}

// MARK: - Run Command

extension SwiftQCCLI {
    struct Run: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run property-based tests"
        )
        
        @Option(name: .shortAndLong, help: "Number of test iterations")
        var count: Int = 100
        
        @Option(name: .shortAndLong, help: "Random seed for reproducible testing")
        var seed: UInt64?
        
        @Option(name: .shortAndLong, help: "Reporter type: console, json, verbose")
        var reporter: String = "console"
        
        @Flag(name: .long, help: "Show verbose output")
        var verbose: Bool = false
        
        @Argument(help: "Property tests to run (or 'all' for built-in examples)")
        var properties: [String] = ["all"]
        
        func run() async throws {
            let selectedReporter = createReporter(type: reporter, verbose: verbose)
            
            if properties.contains("all") || properties.isEmpty {
                await runAllBuiltInProperties(count: count, seed: seed, reporter: selectedReporter)
            } else {
                for property in properties {
                    await runNamedProperty(property, count: count, seed: seed, reporter: selectedReporter)
                }
            }
        }
        
        private func createReporter(type: String, verbose: Bool) -> Reporter {
            switch type.lowercased() {
            case "json":
                return JSONReporter()
            case "verbose":
                return VerboseReporter()
            case "console":
                return ConsoleReporter()
            default:
                return ConsoleReporter()
            }
        }
        
        private func runAllBuiltInProperties(count: Int, seed: UInt64?, reporter: Reporter) async {
            print("🧪 Running SwiftQC Property Tests")
            print("================================")
            
            // Integer properties
            let intResult = await forAll(
                "Integer addition is commutative", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                types: Int.self,
                Int.self
            ) { (a: Int, b: Int) in
                assert(a + b == b + a, "Addition should be commutative")
            }
            printResult("Integer commutativity", intResult)
            
            // String properties
            let stringResult = await forAll(
                "String concatenation length", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                types: String.self,
                String.self
            ) { (s1: String, s2: String) in
                let concatenated = s1 + s2
                assert(concatenated.count == s1.count + s2.count, "Concatenated length should equal sum of parts")
            }
            printResult("String concatenation", stringResult)
            
            // Array properties
            let arrayResult = await forAll(
                "Array reverse twice returns original", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (arr: [Int]) in
                    let doubleReversed = arr.reversed().reversed()
                    assert(Array(doubleReversed) == arr, "Double reverse should return original")
                },
                [Int].self
            )
            printResult("Array reverse", arrayResult)
            
            // Sorting properties
            let sortResult = await forAll(
                "Sorted array is non-decreasing", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (arr: [Int]) in
                    let sorted = arr.sorted()
                    for i in 0..<sorted.count - 1 {
                        assert(sorted[i] <= sorted[i + 1], "Sorted array should be non-decreasing")
                    }
                },
                [Int].self
            )
            printResult("Array sorting", sortResult)
        }
        
        private func runNamedProperty(_ name: String, count: Int, seed: UInt64?, reporter: Reporter) async {
            switch name.lowercased() {
            case "arithmetic", "math":
                await runArithmeticProperties(count: count, seed: seed, reporter: reporter)
            case "strings":
                await runStringProperties(count: count, seed: seed, reporter: reporter)
            case "arrays", "collections":
                await runArrayProperties(count: count, seed: seed, reporter: reporter)
            case "sorting":
                await runSortingProperties(count: count, seed: seed, reporter: reporter)
            default:
                print("❌ Unknown property: \(name)")
                print("Available properties: arithmetic, strings, arrays, sorting")
            }
        }
        
        private func runArithmeticProperties(count: Int, seed: UInt64?, reporter: Reporter) async {
            print("🔢 Arithmetic Properties")
            print("========================")
            
            let commutativeResult = await forAll(
                "Addition is commutative", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                types: Int.self,
                Int.self
            ) { (a: Int, b: Int) in
                assert(a + b == b + a)
            }
            printResult("Addition commutativity", commutativeResult)
            
            let associativeResult = await forAll(
                "Addition is associative", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                types: Int.self,
                Int.self,
                Int.self
            ) { (a: Int, b: Int, c: Int) in
                assert((a + b) + c == a + (b + c))
            }
            printResult("Addition associativity", associativeResult)
            
            let identityResult = await forAll(
                "Zero is additive identity", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (n: Int) in
                    assert(n + 0 == n && 0 + n == n)
                },
                Int.self
            )
            printResult("Additive identity", identityResult)
        }
        
        private func runStringProperties(count: Int, seed: UInt64?, reporter: Reporter) async {
            print("📝 String Properties")
            print("====================")
            
            let lengthResult = await forAll(
                "Concatenation length property", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                types: String.self,
                String.self
            ) { (s1: String, s2: String) in
                assert((s1 + s2).count == s1.count + s2.count)
            }
            printResult("String concatenation", lengthResult)
            
            let emptyResult = await forAll(
                "Empty string is concatenation identity", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (s: String) in
                    assert(s + "" == s && "" + s == s)
                },
                String.self
            )
            printResult("String identity", emptyResult)
        }
        
        private func runArrayProperties(count: Int, seed: UInt64?, reporter: Reporter) async {
            print("📋 Array Properties")
            print("===================")
            
            let reverseResult = await forAll(
                "Double reverse returns original", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (arr: [Int]) in
                    assert(Array(arr.reversed().reversed()) == arr)
                },
                [Int].self
            )
            printResult("Array reverse", reverseResult)
            
            let countResult = await forAll(
                "Map preserves count", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (arr: [Int]) in
                    let mapped = arr.map { $0 * 2 }
                    assert(mapped.count == arr.count)
                },
                [Int].self
            )
            printResult("Map count preservation", countResult)
        }
        
        private func runSortingProperties(count: Int, seed: UInt64?, reporter: Reporter) async {
            print("🔢 Sorting Properties")
            print("=====================")
            
            let orderedResult = await forAll(
                "Sorted array is ordered", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (arr: [Int]) in
                    let sorted = arr.sorted()
                    for i in 0..<sorted.count - 1 {
                        assert(sorted[i] <= sorted[i + 1])
                    }
                },
                [Int].self
            )
            printResult("Sort ordering", orderedResult)
            
            let idempotentResult = await forAll(
                "Sort is idempotent", 
                count: count, 
                seed: seed, 
                reporter: reporter,
                { (arr: [Int]) in
                    let sorted = arr.sorted()
                    assert(sorted.sorted() == sorted)
                },
                [Int].self
            )
            printResult("Sort idempotence", idempotentResult)
        }
        
        private func printResult<T>(_ name: String, _ result: TestResult<T>) {
            switch result {
            case .succeeded(let testsRun):
                print("✅ \(name): \(testsRun) tests passed")
            case .falsified(let value, let error, let shrinks, let seed):
                print("❌ \(name): Failed after \(shrinks) shrinks")
                print("   Counterexample: \(value)")
                print("   Error: \(error)")
                print("   Seed: \(String(describing: seed))")
            }
        }
    }
}

// MARK: - Stateful Command

extension SwiftQCCLI {
    struct Stateful: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run stateful property-based tests"
        )
        
        @Option(name: .shortAndLong, help: "Number of test iterations")
        var count: Int = 100
        
        @Option(name: .shortAndLong, help: "Random seed for reproducible testing")
        var seed: UInt64?
        
        func run() async throws {
            print("🔄 Stateful Testing")
            print("===================")
            print("Stateful testing requires implementing a StateModel.")
            print("This feature demonstrates SwiftQC's stateful testing capabilities")
            print("but requires custom model implementation for your specific system.")
        }
    }
    
    struct Interactive: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Interactive SwiftQC session"
        )
        
        func run() async throws {
            print("🎮 SwiftQC Interactive Mode")
            print("============================")
            print("Welcome to SwiftQC! Type commands to interact with generators.")
            print("Available commands:")
            print("  gen <type> [count] - Generate values (int, string, bool, array)")
            print("  prop <name>        - Run a property test")
            print("  seed <number>      - Set random seed")
            print("  help               - Show this help")
            print("  quit               - Exit")
            print()
            
            var currentSeed: UInt64? = nil
            var xoshiro = Xoshiro(seed: 0)
            
            while true {
                print("swiftqc> ", terminator: "")
                guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !input.isEmpty else { continue }
                
                let parts = input.split(separator: " ").map(String.init)
                let command = parts[0].lowercased()
                
                switch command {
                case "quit", "exit", "q":
                    print("Goodbye! 👋")
                    return
                    
                case "help", "h":
                    print("""
                    Available commands:
                      gen int [count]     - Generate random integers
                      gen string [count]  - Generate random strings  
                      gen bool [count]    - Generate random booleans
                      gen array [count]   - Generate random arrays
                      prop arithmetic     - Test arithmetic properties
                      prop strings        - Test string properties
                      seed <number>       - Set random seed for reproducibility
                      help                - Show this help
                      quit                - Exit interactive mode
                    """)
                    
                case "gen":
                    guard parts.count >= 2 else {
                        print("Usage: gen <type> [count]")
                        continue
                    }
                    
                    let type = parts[1].lowercased()
                    let count = parts.count >= 3 ? Int(parts[2]) ?? 5 : 5
                    
                    switch type {
                    case "int", "integer":
                        print("Generated integers:")
                        for _ in 0..<count {
                            let value = Int.gen.run(using: &xoshiro)
                            print("  \(value)")
                        }
                        
                    case "string":
                        print("Generated strings:")
                        for _ in 0..<count {
                            let value = String.gen.run(using: &xoshiro)
                            print("  \"\(value)\"")
                        }
                        
                    case "bool", "boolean":
                        print("Generated booleans:")
                        for _ in 0..<count {
                            let value = Bool.gen.run(using: &xoshiro)
                            print("  \(value)")
                        }
                        
                    case "array":
                        print("Generated integer arrays:")
                        for _ in 0..<count {
                            let value = [Int].gen.run(using: &xoshiro)
                            print("  \(value)")
                        }
                        
                    default:
                        print("Unknown type: \(type)")
                        print("Available types: int, string, bool, array")
                    }
                    
                case "prop":
                    guard parts.count >= 2 else {
                        print("Usage: prop <name>")
                        continue
                    }
                    
                    let propName = parts[1].lowercased()
                    print("Running property test: \(propName)")
                    
                    switch propName {
                    case "arithmetic", "math":
                        let result = await forAll("Quick arithmetic test", count: 20, seed: currentSeed, types: Int.self, Int.self) { (a: Int, b: Int) in
                            assert(a + b == b + a, "Addition should be commutative")
                        }
                        printInteractiveResult(result)
                        
                    case "strings":
                        let result = await forAll("Quick string test", count: 20, seed: currentSeed, types: String.self, String.self) { (s1: String, s2: String) in
                            assert((s1 + s2).count == s1.count + s2.count, "Concatenation length")
                        }
                        printInteractiveResult(result)
                        
                    default:
                        print("Unknown property: \(propName)")
                        print("Available properties: arithmetic, strings")
                    }
                    
                case "seed":
                    guard parts.count >= 2, let newSeed = UInt64(parts[1]) else {
                        print("Usage: seed <number>")
                        continue
                    }
                    
                    currentSeed = newSeed
                    xoshiro = Xoshiro(seed: newSeed)
                    print("Random seed set to: \(newSeed)")
                    
                default:
                    print("Unknown command: \(command)")
                    print("Type 'help' for available commands")
                }
            }
        }
        
        private func printInteractiveResult<T>(_ result: TestResult<T>) {
            switch result {
            case .succeeded(let testsRun):
                print("✅ Property passed all \(testsRun) tests")
            case .falsified(let value, let error, let shrinks, let seed):
                print("❌ Property failed:")
                print("   Counterexample: \(value)")
                print("   Error: \(error)")
                print("   Shrinks performed: \(shrinks)")
                print("   Seed: \(String(describing: seed))")
            }
        }
    }
    
    struct Examples: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show SwiftQC usage examples"
        )
        
        func run() async throws {
            print("""
            🎯 SwiftQC Examples
            ===================
            
            1. Basic Property Test:
            
            await forAll("Addition is commutative") { (a: Int, b: Int) in
                assert(a + b == b + a)
            }
            
            2. With Custom Configuration:
            
            await forAll("String concatenation", count: 200, seed: 12345) { (s1: String, s2: String) in
                assert((s1 + s2).count == s1.count + s2.count)
            }
            
            3. Array Properties:
            
            await forAll("Reverse twice returns original") { (arr: [Int]) in
                let doubleReversed = arr.reversed().reversed()
                assert(Array(doubleReversed) == arr)
            }
            
            4. Stateful Testing (requires StateModel implementation):
            
            await stateful("My System Model") { (commands: Commands<MyModel>) in
                try await runCommands(commands)
            }
            
            5. Parallel Testing (requires ParallelModel implementation):
            
            await parallel("Concurrent System Test") { (parallelCommands: ParallelCommands<MyModel>) in
                try await runParallelCommands(parallelCommands)
            }
            
            For more examples, see: https://github.com/Aristide021/SwiftQC
            """)
        }
    }
}

// MARK: - Supporting Reporters

struct JSONReporter: Reporter {
    func reportSuccess(description: String, iterations: Int) {
        let json = [
            "status": "success",
            "description": description,
            "iterations": iterations
        ] as [String: Any]
        printJSON(json)
    }
    
    func reportFailure<T>(description: String, input: T, error: Error, file: StaticString, line: UInt) {
        let json = [
            "status": "failure",
            "description": description,
            "input": String(describing: input),
            "error": error.localizedDescription,
            "file": String(describing: file),
            "line": line
        ] as [String: Any]
        printJSON(json)
    }
    
    func reportShrinkProgress<T>(from: T, to: T) {
        let json = [
            "status": "shrinking",
            "from": String(describing: from),
            "to": String(describing: to)
        ] as [String: Any]
        printJSON(json)
    }
    
    func reportFinalCounterexample<T>(description: String, input: T, error: Error, file: StaticString, line: UInt) {
        let json = [
            "status": "counterexample",
            "description": description,
            "input": String(describing: input),
            "error": error.localizedDescription,
            "file": String(describing: file),
            "line": line
        ] as [String: Any]
        printJSON(json)
    }
    
    private func printJSON(_ object: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }
}

struct VerboseReporter: Reporter {
    func reportSuccess(description: String, iterations: Int) {
        print("✅ SUCCESS: '\(description)' - All \(iterations) tests passed")
    }
    
    func reportFailure<T>(description: String, input: T, error: Error, file: StaticString, line: UInt) {
        print("❌ FAILURE: '\(description)'")
        print("   Input: \(input)")
        print("   Error: \(error)")
        print("   Location: \(file):\(line)")
    }
    
    func reportShrinkProgress<T>(from: T, to: T) {
        print("🔍 SHRINKING: \(from) → \(to)")
    }
    
    func reportFinalCounterexample<T>(description: String, input: T, error: Error, file: StaticString, line: UInt) {
        print("🎯 COUNTEREXAMPLE for '\(description)':")
        print("   Minimal input: \(input)")
        print("   Error: \(error)")
        print("   Location: \(file):\(line)")
    }
}
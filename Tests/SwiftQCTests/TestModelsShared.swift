import SwiftQC // Ensure this is imported to see Referenceable and DefaultableResponse

// Reference should be Sendable if it's not already implied by other conformances
struct NoReference: Referenceable, Equatable, Hashable, Sendable {}

enum CounterCommand: Sendable, CustomStringConvertible {
    case increment
    case getValue

    var description: String {
        switch self {
        case .increment: return "increment"
        case .getValue: return "getValue"
        }
    }
}

// Ensure CounterResponse conforms to DefaultableResponse from SwiftQC module
enum CounterResponse: Equatable, Sendable, CustomStringConvertible, DefaultableResponse {
    case ackIncrement
    case value(Int)

    var description: String {
        switch self {
        case .ackIncrement: return "ackIncrement"
        case .value(let v): return "value(\(v))"
        }
    }
    // Conformance to DefaultableResponse
    static var defaultPlaceholderResponse: CounterResponse { .ackIncrement }
}

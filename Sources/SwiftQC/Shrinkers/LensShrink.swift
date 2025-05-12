// public struct Lens<S, A> {
//     public let get: (S) -> A
//     public let set: (A, S) -> S
//     
//     public init(get: @escaping (S) -> A, set: @escaping (A, S) -> S) {
//         self.get = get
//         self.set = set
//     }
// }

// extension Shrinker {
//     public func focus<SubValue>(_ lens: Lens<Value, SubValue>, _ subShrinker: any Shrinker<SubValue>) -> any Shrinker<Value> {
//         LensShrink(lens: lens, baseShrinker: self, subShrinker: subShrinker)
//     }
// }

// private struct LensShrink<S, A>: Shrinker {
//     // Implementation...
// }
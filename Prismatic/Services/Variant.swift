import Foundation

/// Which build this is. Chosen at compile time by the Xcode target.
enum Variant {
    case standard, trollStore, jailbreak
    static var current: Variant {
        #if PRISMATIC_JAILBREAK
        return .jailbreak
        #elseif PRISMATIC_TROLLSTORE
        return .trollStore
        #else
        return .standard
        #endif
    }
    var canDecrypt: Bool { self != .standard }
}

import UIKit

/// JIT = CS_DEBUGGED. A debugger-style helper app has to attach (or launch us under a debugger) to set it.
enum JIT {
    /// Real flag only: no assumptions per variant.
    static var isEnabled: Bool { PrismaticIsJITEnabled() }
    /// Everything except a jailbreak needs it to map the game's re-signed code.
    static var required: Bool { Variant.current != .jailbreak }

    /// URL that asks a helper to start Prismatic with JIT. Opening it while we are about to exit makes the helper
    /// launch the NEW process under its debugger, which is how LiveContainer gets JIT for the guest.
    @MainActor static func enablerURL() -> URL? {
        let bid = Bundle.main.bundleIdentifier ?? ""
        let candidates = ["apple-magnifier://enable-jit?bundle-id=\(bid)",   // TrollStore
                          "stikjit://enable-jit?bundle-id=\(bid)",           // StikJIT
                          "sidestore://enable-jit?bid=\(bid)"]               // SideStore
        for c in candidates {
            if let u = URL(string: c), UIApplication.shared.canOpenURL(u) { return u }
        }
        return nil
    }
}

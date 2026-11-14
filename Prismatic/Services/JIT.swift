import UIKit

/// JIT status + requesting it from a companion app (StikJIT / SideStore), as LiveContainer does.
enum JIT {
    static var isEnabled: Bool { PrismaticIsJITEnabled() }

    /// Asks an enabler app to attach a debugger to Prismatic, then returns here.
    @MainActor static func request() {
        let bid = Bundle.main.bundleIdentifier ?? ""
        let candidates = ["stikjit://enable-jit?bundle-id=\(bid)&scriptName=prismatic",
                          "sidestore://enable-jit?bid=\(bid)"]
        for c in candidates {
            if let u = URL(string: c), UIApplication.shared.canOpenURL(u) {
                UIApplication.shared.open(u); return
            }
        }
    }
}

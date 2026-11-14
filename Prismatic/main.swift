import UIKit
import SwiftUI

// Entry point. A queued game launch runs HERE, in a fresh process, before UIKit starts: the game calls
// UIApplicationMain itself, which can only happen once per process.
PrismaticInstallCrashHandlers()
PLog.log("--- Prismatic start (\(Variant.current), pid \(getpid()), jit \(PrismaticIsJITEnabled()))")

if let req = PendingLaunch.take() {
    PLog.log("pending launch: \(req.bundleId) geode=\(req.geode ?? "none")")
    var ready = true
    if JIT.required && !JIT.isEnabled {
        for _ in 0..<50 where !JIT.isEnabled { usleep(100_000) } // give the JIT helper up to 5 s to attach
        if !JIT.isEnabled {
            ready = false
            LaunchStatus.fail("JIT wasn't enabled for the new process. Install StikJIT or SideStore and allow JIT for Prismatic, then try again.")
        }
    }
    if ready {
        PrismaticLaunchGuest(req.app, req.data, req.bundleId, req.geode)
        LaunchStatus.fail("The game didn't start. Open Logs for details.") // only reached on failure
    }
}

PrismaticApp.main()

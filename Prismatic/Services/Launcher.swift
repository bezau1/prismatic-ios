import UIKit

enum LaunchError: LocalizedError {
    case encrypted, geodeUnsupported, geodeMissing
    var errorDescription: String? {
        switch self {
        case .encrypted: return "This build is still FairPlay-encrypted. Decrypt it first (TrollStore/Jailbreak build) or import a decrypted IPA."
        case .geodeUnsupported: return "Geode mode supports Geometry Dash 2.2 through 2.2081 only."
        case .geodeMissing: return "Geode isn't installed for this instance yet."
        }
    }
}

/// A launch request that survives the process restart (the game can only start in a fresh process, before UIKit).
enum PendingLaunch {
    struct Request: Codable { var app: String; var data: String; var bundleId: String; var geode: String? }
    private static let key = "prismatic.pendingLaunch"
    static func save(_ r: Request) {
        UserDefaults.standard.set(try? JSONEncoder().encode(r), forKey: key)
        UserDefaults.standard.synchronize()
    }
    static func take() -> Request? {
        guard let d = UserDefaults.standard.data(forKey: key), let r = try? JSONDecoder().decode(Request.self, from: d) else { return nil }
        UserDefaults.standard.removeObject(forKey: key); UserDefaults.standard.synchronize()
        return r
    }
}

/// Why the last launch attempt ended up back in the UI.
enum LaunchStatus {
    private static let key = "prismatic.lastLaunchError"
    static func fail(_ m: String) { PLog.log("launch failed: \(m)"); UserDefaults.standard.set(m, forKey: key); UserDefaults.standard.synchronize() }
    static func take() -> String? {
        let m = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        return m
    }
}

enum Launcher {
    /// Queues the launch and restarts Prismatic; the new process loads the game before any UI exists.
    @MainActor static func launch(_ inst: Instance, geode: Bool) throws {
        if inst.encrypted { throw LaunchError.encrypted }
        if geode && !GeodeManager.isSupported(inst.gdVersion) { throw LaunchError.geodeUnsupported }
        if geode && !FileManager.default.fileExists(atPath: GeodeManager.dylibPath(inst)) { throw LaunchError.geodeMissing }
        PendingLaunch.save(.init(app: inst.appBundle.path, data: inst.dataDir.path, bundleId: inst.bundleId,
                                 geode: geode ? GeodeManager.dylibPath(inst) : nil))
        PLog.log("queued launch of \(inst.name) (GD \(inst.gdVersion), geode=\(geode)); restarting")
        relaunch()
    }

    @MainActor private static func relaunch() {
        let selfURL = URL(string: "prismatic://relaunch")!
        let url = (JIT.required ? JIT.enablerURL() : nil) ?? selfURL
        PLog.log("relaunch via \(url.absoluteString)")
        // Same trick LiveContainer uses: ask iOS to open the URL, and quit once it has been handed over.
        UIApplication.shared.open(url, options: [:]) { ok in PLog.log("open -> \(ok); exiting"); exit(0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { exit(0) } // never hang if the callback doesn't fire
    }
}

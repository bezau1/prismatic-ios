import Foundation

enum DecryptError: LocalizedError {
    case unavailable, notInstalled, versionMismatch(installed: String, wanted: String), failed(String)
    var errorDescription: String? {
        switch self {
        case .unavailable: return "This build can't decrypt. Use the TrollStore or Jailbreak build, or import a decrypted IPA."
        case .notInstalled: return "Geometry Dash isn't installed from the App Store on this device."
        case .versionMismatch(let i, let w): return "Installed GD is \(i) but this instance is \(w). Use \"Install & decrypt\" on a jailbreak, or make a new instance from the installed copy."
        case .failed(let m): return m
        }
    }
}

enum Decryptor {
    static var installedPath: String? { PrismaticInstalledAppPath(AppStoreClient.gdBundleId) }
    static var installedVersion: String? {
        guard let p = installedPath else { return nil }
        return NSDictionary(contentsOfFile: p + "/Info.plist")?["CFBundleShortVersionString"] as? String
    }

    /// TrollStore + Jailbreak: dump the currently installed GD (TrollDecrypt method).
    static func decryptInstalled(into inst: Instance) throws {
        guard Variant.current.canDecrypt else { throw DecryptError.unavailable }
        guard let src = installedPath, let v = installedVersion else { throw DecryptError.notInstalled }
        if v != inst.gdVersion { throw DecryptError.versionMismatch(installed: v, wanted: inst.gdVersion) }
        try FileManager.default.createDirectory(at: inst.appBundle.deletingLastPathComponent(), withIntermediateDirectories: true)
        var err: NSString?
        if !PrismaticDecryptBundle(src, inst.appBundle.path, &err) { throw DecryptError.failed(err as String? ?? "decrypt failed") }
    }

    /// Jailbreak only: put this instance's exact build on the device, dump it, done. Overwrites the App Store copy.
    static func installAndDecrypt(_ inst: Instance) throws {
        guard Variant.current == .jailbreak else { throw DecryptError.unavailable }
        if installedVersion != inst.gdVersion {
            var err: NSString?
            let ipa = inst.root.appendingPathComponent("game.ipa").path
            guard FileManager.default.fileExists(atPath: ipa) else { throw DecryptError.failed("Original IPA is missing; recreate the instance.") }
            if !PrismaticInstallIPA(ipa, &err) { throw DecryptError.failed(err as String? ?? "install failed") }
            for _ in 0..<60 where installedVersion != inst.gdVersion { Thread.sleep(forTimeInterval: 1) }
        }
        try decryptInstalled(into: inst)
    }
}

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
        try Signer.signBundle(inst.appBundle, bundleId: inst.bundleId) // original signature no longer matches the decrypted pages
    }

    /// TrollStore + Jailbreak, one-time per instance:
    /// install this instance's exact build via installd (FairPlay intact) -> dump it -> delete the app.
    /// Afterwards the instance holds a decrypted copy and never touches FairPlay again.
    static func installAndDecrypt(_ inst: Instance) throws {
        guard Variant.current.canDecrypt else { throw DecryptError.unavailable }
        let ipa = inst.root.appendingPathComponent("game.ipa").path
        var err: NSString?
        if installedVersion != inst.gdVersion {
            guard FileManager.default.fileExists(atPath: ipa) else { throw DecryptError.failed("Original IPA is missing; recreate the instance.") }
            // installd won't downgrade over a newer copy, so clear the current one first
            if installedPath != nil { _ = PrismaticUninstallApp(AppStoreClient.gdBundleId, &err) }
            if !PrismaticInstallIPA(ipa, &err) { throw DecryptError.failed(err as String? ?? "install failed") }
            for _ in 0..<60 where installedVersion != inst.gdVersion { Thread.sleep(forTimeInterval: 1) }
            guard installedVersion == inst.gdVersion else { throw DecryptError.failed("Install didn't finish or the version differs.") }
        }
        try decryptInstalled(into: inst)
        guard !MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent("GeometryJump")) else {
            throw DecryptError.failed("Dump finished but the binary is still marked encrypted.")
        }
        // done with FairPlay: remove the App Store copy and the original IPA
        if !PrismaticUninstallApp(AppStoreClient.gdBundleId, &err) { throw DecryptError.failed(err as String? ?? "couldn't delete installed GD") }
        try? FileManager.default.removeItem(atPath: ipa)
    }
}

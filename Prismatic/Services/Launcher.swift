import Foundation

enum LaunchError: LocalizedError {
    case encrypted, needsJIT, geodeUnsupported
    var errorDescription: String? {
        switch self {
        case .encrypted: return "This build is still FairPlay-encrypted. Decrypt it first (TrollStore/Jailbreak build) or import a decrypted IPA."
        case .needsJIT: return "JIT isn't enabled. Enable it with StikJIT or SideStore, then tap Launch again."
        case .geodeUnsupported: return "Geode mode supports Geometry Dash 2.2 through 2.2081 only."
        }
    }
}

enum Launcher {
    /// Jailbreak "decrypt on the go": decrypts first if needed. Other builds just launch.
    @MainActor static func prepareAndLaunch(_ inst: inout Instance, geode: Bool) throws {
        if inst.encrypted && Variant.current == .jailbreak {
            try Decryptor.installAndDecrypt(inst)
            inst.encrypted = MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent("GeometryJump"))
        }
        try launch(inst, geode: geode)
    }

    /// Runs the instance inside Prismatic's own process (LiveContainer-style).
    @MainActor static func launch(_ inst: Instance, geode: Bool) throws {
        if inst.encrypted { throw LaunchError.encrypted }
        if geode && !GeodeManager.isSupported(inst.gdVersion) { throw LaunchError.geodeUnsupported }
        if !JIT.isEnabled { JIT.request(); throw LaunchError.needsJIT }
        PrismaticLaunchGuest(inst.appBundle.path, inst.dataDir.path, inst.bundleId,
                             geode ? GeodeManager.dylibPath(inst) : nil)
    }
}

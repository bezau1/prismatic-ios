import Foundation

enum LaunchError: LocalizedError {
    case encrypted, needsJIT, geodeUnsupported
    var errorDescription: String? {
        switch self {
        case .encrypted: return "This build is still FairPlay-encrypted and can't run outside the App Store install. Import a decrypted IPA for this version."
        case .needsJIT: return "JIT isn't enabled. Enable it with StikJIT or SideStore, then tap Launch again."
        case .geodeUnsupported: return "Geode mode supports Geometry Dash 2.2 through 2.2081 only."
        }
    }
}

enum Launcher {
    /// Runs the instance inside Prismatic's own process (LiveContainer-style).
    @MainActor static func launch(_ inst: Instance, geode: Bool) throws {
        if inst.encrypted { throw LaunchError.encrypted }
        if geode && !GeodeManager.isSupported(inst.gdVersion) { throw LaunchError.geodeUnsupported }
        if !JIT.isEnabled { JIT.request(); throw LaunchError.needsJIT }
        // Does not return on success: hands the process over to the guest's main().
        PrismaticLaunchGuest(inst.appBundle.path, inst.dataDir.path, inst.bundleId,
                             geode ? GeodeManager.dylibPath(inst) : nil)
    }
}

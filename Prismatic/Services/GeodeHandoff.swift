import UIKit

/// "Geode mode" = hand the decrypted game to the official Geode iOS launcher, which does the patching itself.
/// That launcher can't be driven from another app (its URL scheme only takes mods), so the IPA is prepared in a
/// place the Files app can see and the user picks it once inside the launcher's "Import IPA".
enum GeodeHandoff {
    static let releasesURL = URL(string: "https://github.com/geode-sdk/ios-launcher/releases")!
    /// The newest launcher targets exactly this Geometry Dash version.
    static let newestLauncherGD = "2.2081"

    @MainActor static var launcherInstalled: Bool {
        UIApplication.shared.canOpenURL(URL(string: "geode://launch")!)
    }
    @MainActor static func openLauncher() {
        UIApplication.shared.open(URL(string: "geode://launch")!)
    }
    @MainActor static func openFiles(at dir: URL) {
        // Files understands shareddocuments:// + a path
        if let u = URL(string: dir.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")) {
            UIApplication.shared.open(u)
        }
    }
    /// Writes the clean decrypted IPA to Documents/Exports and returns it.
    static func prepare(_ inst: Instance) throws -> URL { try IPAExporter.export(inst) }
}

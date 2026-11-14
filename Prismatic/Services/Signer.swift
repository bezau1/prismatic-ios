import Foundation

/// Ad-hoc re-signing with LiveContainer's ZSign, run after the binary is decrypted.
enum Signer {
    private static let entitlements = Data("""
    <?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
    <key>get-task-allow</key><true/></dict></plist>
    """.utf8)

    /// Signs every Mach-O in the bundle (main exe, frameworks, dylibs).
    static func signBundle(_ app: URL, bundleId: String) throws {
        var targets: [String] = []
        if let en = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil) {
            for case let u as URL in en {
                if u.pathExtension == "dylib" || (u.deletingLastPathComponent().pathExtension == "framework"
                    && u.lastPathComponent == u.deletingLastPathComponent().deletingPathExtension().lastPathComponent) {
                    targets.append(u.path)
                }
            }
        }
        if let exe = NSDictionary(contentsOf: app.appendingPathComponent("Info.plist"))?["CFBundleExecutable"] as? String {
            targets.append(app.appendingPathComponent(exe).path)
        }
        // Convert the game executable into a loadable dylib first (this changes the file, so it must precede signing).
        if let exe = NSDictionary(contentsOf: app.appendingPathComponent("Info.plist"))?["CFBundleExecutable"] as? String,
           let problem = PrismaticPatchExecutable(app.appendingPathComponent(exe).path) {
            throw StoreError.message("Couldn't prepare the game binary: \(problem)")
        }
        for t in targets where !sign(t, bundleId: bundleId) { throw StoreError.message("Signing failed for \(t)") }
    }

    @discardableResult
    static func sign(_ path: String, bundleId: String) -> Bool {
        ZSigner.adhocSignMachO(atPath: path, bundleId: bundleId, entitlementData: entitlements)
    }
}

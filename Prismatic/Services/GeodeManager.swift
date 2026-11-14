import Foundation
import ZIPFoundation

/// Installs Geode for iOS into an instance, the way Geode's own iOS launcher does:
/// loader from api.geode-sdk.org (picked per Geometry Dash version), resources from the GitHub release.
enum GeodeManager {
    static let supported: ClosedRange<Double> = 2.2...2.2081

    static func isSupported(_ gdVersion: String) -> Bool {
        guard let v = Double(gdVersion) else { return false }
        return supported.contains(v)
    }
    static func dylibPath(_ inst: Instance) -> String { inst.root.appendingPathComponent("Geode.ios.dylib").path }

    private static func json(_ url: URL) async throws -> [String: Any] {
        let (d, r) = try await URLSession.shared.pData(from: url)
        if let http = r as? HTTPURLResponse, http.statusCode >= 500 { throw StoreError.http(http.statusCode) }
        guard let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            throw StoreError.message("Geode's server sent a reply I couldn't read (\(url.host ?? "?")).")
        }
        return obj
    }

    private static func unzip(_ url: URL, to dir: URL) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: dir)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fm.unzipItem(at: url, to: dir)
    }

    /// Installs the newest Geode build made for this instance's Geometry Dash version; returns its tag.
    static func install(into inst: Instance) async throws -> String {
        let fm = FileManager.default
        // 1. Loader: Geode's API chooses the right build for the game version.
        let api = URL(string: "https://api.geode-sdk.org/v1/loader/versions/latest?gd=\(inst.gdVersion)")!
        let reply = try await json(api)
        if let e = reply["error"] as? String, !e.isEmpty { throw StoreError.message("Geode has no build for Geometry Dash \(inst.gdVersion): \(e)") }
        guard let payload = reply["payload"] as? [String: Any],
              let tag = payload["tag"] as? String,
              let ios = (payload["downloads"] as? [String: Any])?["ios"] as? [String: Any],
              let urlString = ios["url"] as? String, let zipURL = URL(string: urlString)
        else { throw StoreError.message("Geode has no iOS build for Geometry Dash \(inst.gdVersion).") }
        PLog.log("Geode \(tag) for GD \(inst.gdVersion): \(urlString)")

        let (zipTmp, _) = try await URLSession.shared.pDownload(from: zipURL)
        let work = fm.temporaryDirectory.appendingPathComponent("geode-\(UUID().uuidString)")
        try unzip(zipTmp, to: work)
        guard let found = fm.enumerator(at: work, includingPropertiesForKeys: nil)?
            .compactMap({ $0 as? URL }).first(where: { $0.lastPathComponent == "Geode.ios.dylib" })
        else { throw StoreError.message("The Geode download didn't contain Geode.ios.dylib.") }
        let dest = URL(fileURLWithPath: dylibPath(inst))
        try? fm.removeItem(at: dest); try fm.moveItem(at: found, to: dest)
        try? fm.removeItem(at: work); try? fm.removeItem(at: zipTmp)
        Signer.sign(dest.path, bundleId: inst.bundleId)

        // 2. Resources (textures, loader UI): where Geode expects them inside the game's save folder.
        do {
            let rel = try await json(URL(string: "https://api.github.com/repos/geode-sdk/geode/releases/latest")!)
            if let assets = rel["assets"] as? [[String: Any]],
               let res = assets.first(where: { ($0["name"] as? String) == "resources.zip" }),
               let s = res["browser_download_url"] as? String, let u = URL(string: s) {
                let (rzip, _) = try await URLSession.shared.pDownload(from: u)
                let target = inst.dataDir.appendingPathComponent("Library/Application Support/GeometryDash/game/geode/resources/geode.loader")
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try unzip(rzip, to: target)
                try? fm.removeItem(at: rzip)
            } else { PLog.log("Geode resources.zip not found in the latest release; continuing without") }
        } catch { PLog.log("Geode resources download failed: \(error.localizedDescription); continuing") }
        return tag
    }
}

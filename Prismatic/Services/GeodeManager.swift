import Foundation

/// Fetches Geode for iOS from GitHub releases and drops it into an instance.
/// "Geode mode" is available for GD 2.2 → 2.2081 (the range Geode iOS targets).
enum GeodeManager {
    static let supported: ClosedRange<Double> = 2.2...2.2081
    static let repo = "geode-sdk/ios-launcher-releases" // placeholder: set to the real iOS loader release repo

    static func isSupported(_ gdVersion: String) -> Bool {
        guard let v = Double(gdVersion) else { return false }
        return supported.contains(v)
    }

    struct Release: Decodable { struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String; let assets: [Asset] }

    /// Installs the newest Geode build and returns its tag.
    static func install(into inst: Instance) async throws -> String {
        let api = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        let (d, _) = try await URLSession.shared.data(from: api)
        let rel = try JSONDecoder().decode(Release.self, from: d)
        guard let asset = rel.assets.first(where: { $0.name.hasSuffix(".dylib") && $0.name.lowercased().contains("ios") })
        else { throw StoreError.malformed("no iOS Geode dylib in release \(rel.tag_name)") }
        let (tmp, _) = try await URLSession.shared.download(from: asset.browser_download_url)
        let fm = FileManager.default
        try fm.createDirectory(at: inst.geodeDir, withIntermediateDirectories: true)
        let dest = inst.root.appendingPathComponent("Geode.ios.dylib")
        try? fm.removeItem(at: dest); try fm.moveItem(at: tmp, to: dest)
        return rel.tag_name
    }
    static func dylibPath(_ inst: Instance) -> String { inst.root.appendingPathComponent("Geode.ios.dylib").path }
}

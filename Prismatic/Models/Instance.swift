import Foundation

/// One installed copy of Geometry Dash, like a Minecraft launcher "instance".
struct Instance: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var gdVersion: String          // e.g. "2.2074"
    var externalVersionId: String? // App Store version id it was pulled from
    var geodeEnabled = false
    var geodeVersion: String?      // installed Geode build, if any
    var encrypted = true           // FairPlay cryptid still set on the main binary
    var created = Date()

    var bundleId: String { "com.robtop.geometryjump" }
    var root: URL { InstanceStore.baseURL.appendingPathComponent(id.uuidString) }
    var appBundle: URL { root.appendingPathComponent("App/GeometryJump.app") }
    var dataDir: URL { root.appendingPathComponent("Data") }   // guest's fake $HOME
    /// Clean decrypted IPA (before Prismatic patches/signs it): what other launchers, e.g. Geode's, should get.
    var pristineIPA: URL { root.appendingPathComponent("decrypted.ipa") }
    var geodeDir: URL { dataDir.appendingPathComponent("Documents/geode") }
}

import Foundation
import ZIPFoundation

/// Downloads an IPA for an instance, injects the sinf, unzips it, inspects FairPlay state.
enum IPAInstaller {
    static func install(version: GDVersion, account: AppStoreAccount, into inst: Instance,
                        progress: @escaping (Double) -> Void) async throws -> Instance {
        let client = AppStoreClient()
        let app = try await client.trackId()
        let info = try await client.downloadInfo(account: account, appId: app, versionId: version.externalId)
        let fm = FileManager.default
        try fm.createDirectory(at: inst.root.appendingPathComponent("App"), withIntermediateDirectories: true)
        try fm.createDirectory(at: inst.dataDir, withIntermediateDirectories: true)

        let ipa = inst.root.appendingPathComponent("game.ipa")
        let (tmp, _) = try await URLSession.shared.pDownload(from: info.url)
        try? fm.removeItem(at: ipa); try fm.moveItem(at: tmp, to: ipa)
        progress(0.8)
        try await extract(ipa: ipa, sinf: info.sinf, into: inst)
        if !Variant.current.canDecrypt { try? fm.removeItem(at: ipa) } // privileged builds reinstall from it to decrypt
        progress(1)
        var i = inst; i.externalVersionId = version.externalId; i.gdVersion = version.version
        i.encrypted = MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent("GeometryJump"))
        return i
    }

    /// Also used for "Import IPA" (a decrypted dump).
    static func extract(ipa: URL, sinf: Data?, into inst: Instance) async throws {
        let fm = FileManager.default
        let tmp = inst.root.appendingPathComponent("unzip")
        try? fm.removeItem(at: tmp)
        try fm.unzipItem(at: ipa, to: tmp)
        let payload = tmp.appendingPathComponent("Payload")
        guard let app = try fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else { throw StoreError.malformed("no .app in ipa") }
        try? fm.removeItem(at: inst.appBundle)
        try fm.moveItem(at: app, to: inst.appBundle)
        try? fm.removeItem(at: tmp)
        if !MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent("GeometryJump")) {
            try Signer.signBundle(inst.appBundle, bundleId: inst.bundleId) // decrypted import: re-sign
        }
        if let s = sinf { // keep the FairPlay receipt next to the binary, as installd would
            let sc = inst.appBundle.appendingPathComponent("SC_Info")
            try fm.createDirectory(at: sc, withIntermediateDirectories: true)
            try s.write(to: sc.appendingPathComponent("GeometryJump.sinf"))
        }
    }
}

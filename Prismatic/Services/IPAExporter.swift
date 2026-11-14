import Foundation
import SwiftUI
import UIKit
import ZIPFoundation

/// Packs decrypted instances into normal IPAs, for other sideloaders and for handing to Geode's launcher.
enum IPAExporter {
    /// Zips an .app into an IPA, leaving out the FairPlay receipt (it is tied to your Apple ID and useless once decrypted).
    static func pack(app: URL, to out: URL) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString)")
        let payload = work.appendingPathComponent("Payload")
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let copy = payload.appendingPathComponent(app.lastPathComponent)
        try fm.copyItem(at: app, to: copy)
        try? fm.removeItem(at: copy.appendingPathComponent("SC_Info"))
        try? fm.removeItem(at: out)
        try fm.zipItem(at: payload, to: out, shouldKeepParent: true)
    }

    /// Documents/Exports, which shows up in the Files app under Prismatic.
    static func exportsDir() throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Exports")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func export(_ inst: Instance) throws -> URL {
        guard !inst.encrypted else { throw StoreError.message("This instance is still encrypted; decrypt it first.") }
        let fm = FileManager.default
        let out = try exportsDir().appendingPathComponent("Prismatic-GD-\(inst.gdVersion)-decrypted.ipa")
        try? fm.removeItem(at: out)
        if fm.fileExists(atPath: inst.pristineIPA.path) {
            try fm.copyItem(at: inst.pristineIPA, to: out)   // clean copy, as imported/decrypted
        } else {
            try pack(app: inst.appBundle, to: out)           // older instances: best effort from the patched app
        }
        return out
    }
}

struct ExportItem: Identifiable { let id = UUID(); let url: URL }

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

import Foundation
import UIKit
import ZIPFoundation

/// Packs a decrypted instance back into a normal IPA that any sideloader (non-TrollStore devices) can import.
enum IPAExporter {
    static func export(_ inst: Instance) throws -> URL {
        guard !MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent("GeometryJump")) else {
            throw StoreError.malformed("This instance is still encrypted; decrypt it first.")
        }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString)")
        let payload = work.appendingPathComponent("Payload")
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        let app = payload.appendingPathComponent("GeometryJump.app")
        try fm.copyItem(at: inst.appBundle, to: app)
        // The FairPlay receipt is bound to your Apple ID and useless once decrypted: don't ship it.
        try? fm.removeItem(at: app.appendingPathComponent("SC_Info"))
        let out = fm.temporaryDirectory.appendingPathComponent("Prismatic-GD-\(inst.gdVersion)-decrypted.ipa")
        try? fm.removeItem(at: out)
        try fm.zipItem(at: payload, to: out, shouldKeepParent: true)
        try? fm.removeItem(at: work)
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

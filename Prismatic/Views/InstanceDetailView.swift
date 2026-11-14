import SwiftUI
import UniformTypeIdentifiers

struct InstanceDetailView: View {
    @EnvironmentObject var store: InstanceStore
    @State var instance: Instance
    @State private var message: String?, importing = false, busy = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: instance.gdVersion)
                LabeledContent("Binary", value: instance.encrypted ? "FairPlay-encrypted" : "Decrypted")
                LabeledContent("JIT", value: JIT.isEnabled ? "Enabled" : "Not enabled")
            }
            Section {
                Button("Launch") { run(geode: false) }.disabled(instance.encrypted)
                Button("Geode mode") { Task { await geode() } }
                    .disabled(instance.encrypted || !GeodeManager.isSupported(instance.gdVersion) || busy)
                if !GeodeManager.isSupported(instance.gdVersion) {
                    Text("Geode supports GD 2.2 – 2.2081.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if instance.encrypted {
                Section(footer: Text("App Store builds are FairPlay-encrypted to your device and can't run re-signed. Import a decrypted IPA of this same version to make it launchable.")) {
                    Button("Import decrypted IPA…") { importing = true }
                }
            }
            if let message { Text(message).foregroundStyle(.orange) }
        }
        .navigationTitle(instance.name)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip, .data]) { r in
            if case .success(let u) = r { Task { await importIPA(u) } }
        }
    }

    func run(geode: Bool) {
        do { try Launcher.launch(instance, geode: geode) } catch { message = error.localizedDescription }
    }
    func geode() async {
        busy = true; defer { busy = false }
        do {
            if instance.geodeVersion == nil {
                instance.geodeVersion = try await GeodeManager.install(into: instance)
                instance.geodeEnabled = true; store.update(instance)
            }
            run(geode: true)
        } catch { message = error.localizedDescription }
    }
    func importIPA(_ url: URL) async {
        _ = url.startAccessingSecurityScopedResource(); defer { url.stopAccessingSecurityScopedResource() }
        do {
            try await IPAInstaller.extract(ipa: url, sinf: nil, into: instance)
            instance.encrypted = MachOInspector.isEncrypted(instance.appBundle.appendingPathComponent("GeometryJump"))
            store.update(instance)
            message = instance.encrypted ? "That IPA is still encrypted." : "Imported. Ready to launch."
        } catch { message = error.localizedDescription }
    }
}

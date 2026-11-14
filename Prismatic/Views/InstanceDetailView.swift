import SwiftUI
import UniformTypeIdentifiers

struct InstanceDetailView: View {
    @EnvironmentObject var store: InstanceStore
    @State var instance: Instance
    @State private var message: String?
    @State private var importing = false
    @State private var busy = false

    func info(_ k: String, _ v: String) -> some View { HStack { Text(k); Spacer(); Text(v).foregroundColor(.secondary) } }

    var body: some View {
        Form {
            Section {
                info("Version", instance.gdVersion)
                info("Build", Variant.current == .jailbreak ? "Jailbreak" : Variant.current == .trollStore ? "TrollStore" : "Standard")
                info("Binary", instance.encrypted ? "FairPlay-encrypted" : "Decrypted")
                info("JIT", JIT.isEnabled ? "Enabled" : "Not enabled")
            }
            Section(footer: footer) {
                Button("Launch") { Task { await run(geode: false) } }
                    .disabled(busy || (instance.encrypted && !Variant.current.canDecrypt))
                Button("Geode mode") { Task { await run(geode: true) } }
                    .disabled(busy || !GeodeManager.isSupported(instance.gdVersion)
                              || (instance.encrypted && !Variant.current.canDecrypt))
            }
            if instance.encrypted && Variant.current.canDecrypt {
                Section(footer: Text("Installs GD \(instance.gdVersion) from the App Store IPA, decrypts it, then deletes the installed app. Done once; after that this instance runs without FairPlay.")) {
                    Button("Install & decrypt now") { Task { await installDecrypt() } }.disabled(busy)
                }
            }
            if instance.encrypted && Variant.current == .standard {
                Section(footer: Text("This build can't decrypt. Import a decrypted IPA of this version, or use the TrollStore/Jailbreak build.")) {
                    Button("Import decrypted IPA…") { importing = true }
                }
            }
            if let message = message { Text(message).foregroundColor(.orange) }
        }
        .navigationTitle(instance.name)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip, .data]) { r in
            if case .success(let u) = r { Task { await importIPA(u) } }
        }
    }

    var footer: Text {
        Text(!GeodeManager.isSupported(instance.gdVersion) ? "Geode supports GD 2.2 – 2.2081."
             : (Variant.current.canDecrypt && instance.encrypted ? "First launch installs and decrypts this build, then deletes the App Store copy of GD (once)." : ""))
    }

    @MainActor func run(geode: Bool) async {
        busy = true; message = geode ? "Preparing Geode…" : "Launching…"; defer { busy = false }
        do {
            if geode && instance.geodeVersion == nil {
                instance.geodeVersion = try await GeodeManager.install(into: instance)
                instance.geodeEnabled = true; store.update(instance)
            }
            try Launcher.prepareAndLaunch(&instance, geode: geode)
            store.update(instance)
        } catch { message = error.localizedDescription }
    }
    @MainActor func installDecrypt() async {
        busy = true; message = "Installing, decrypting, cleaning up… this can take a minute."; defer { busy = false }
        do {
            try Decryptor.installAndDecrypt(instance)
            instance.encrypted = MachOInspector.isEncrypted(instance.appBundle.appendingPathComponent("GeometryJump"))
            store.update(instance); message = instance.encrypted ? "Still encrypted." : "Decrypted. Ready to launch."
        } catch { message = error.localizedDescription }
    }
    @MainActor func importIPA(_ url: URL) async {
        _ = url.startAccessingSecurityScopedResource(); defer { url.stopAccessingSecurityScopedResource() }
        do {
            try await IPAInstaller.extract(ipa: url, sinf: nil, into: instance)
            instance.encrypted = MachOInspector.isEncrypted(instance.appBundle.appendingPathComponent("GeometryJump"))
            store.update(instance)
            message = instance.encrypted ? "That IPA is still encrypted." : "Imported. Ready to launch."
        } catch { message = error.localizedDescription }
    }
}

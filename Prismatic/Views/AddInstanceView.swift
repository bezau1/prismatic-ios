import SwiftUI
import UniformTypeIdentifiers

struct AddInstanceView: View {
    @EnvironmentObject var store: InstanceStore
    @EnvironmentObject var acct: AccountState
    @Environment(\.presentationMode) var pm
    @State private var name = "Geometry Dash"
    @State private var importing = false
    @State private var signingIn = false
    @State private var versions: [GDVersion] = []
    @State private var picked: GDVersion?
    @State private var progress: Double?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            Form {
                TextField("Instance name", text: $name)

                // The normal path: no account, no network.
                Section(header: Text("Import"),
                        footer: Text("Pick a decrypted Geometry Dash .ipa from Files. Nothing is sent anywhere.")) {
                    Button(busy ? "Importing…" : "Import IPA…") { importing = true }.disabled(busy)
                }

                if Variant.current.canDecrypt {
                    Section(header: Text("From this device"),
                            footer: Text(Decryptor.installedVersion.map { "Installed: GD \($0)" } ?? "Geometry Dash isn't installed.")) {
                        Button(busy ? "Decrypting…" : "Use installed copy (decrypt)") { Task { await fromInstalled() } }.disabled(busy).disabled(Decryptor.installedVersion == nil)
                    }
                }

                Section(header: Text("Pull from App Store (experimental)")) {
                    if acct.account == nil {
                        Button("Sign in with Apple ID…") { signingIn = true }
                    } else {
                        if versions.isEmpty && error == nil { ProgressView() }
                        ForEach(versions) { v in
                            Button { picked = v } label: {
                                HStack { Text(v.version); Spacer(); if picked == v { Image(systemName: "checkmark") } }
                            }.foregroundColor(.primary)
                        }
                        if picked != nil {
                            Button("Download selected version") { Task { await create() } }.disabled(progress != nil)
                        }
                    }
                }

                if let progress = progress { ProgressView(value: progress) }
                if let error = error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle("New instance")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { pm.wrappedValue.dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { r in
                if case .success(let u) = r { Task { await importIPA(u) } }
            }
            .sheet(isPresented: $signingIn) { SignInView().environmentObject(acct) }
            .onAppear { Task { await load() } }
            .onChange(of: acct.account?.email) { _ in Task { await load() } }
        }
    }

    @MainActor func importIPA(_ url: URL) async {
        busy = true; error = nil; defer { busy = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var inst = Instance(name: name, gdVersion: "?")
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: inst.root, withIntermediateDirectories: true)
            try fm.createDirectory(at: inst.dataDir, withIntermediateDirectories: true)
            let ipa = inst.root.appendingPathComponent("game.ipa")
            try fm.copyItem(at: url, to: ipa)
            try await IPAInstaller.extract(ipa: ipa, sinf: nil, into: inst)

            let info = NSDictionary(contentsOf: inst.appBundle.appendingPathComponent("Info.plist"))
            inst.gdVersion = (info?["CFBundleShortVersionString"] as? String) ?? "?"
            if name == "Geometry Dash" { inst.name = "Geometry Dash \(inst.gdVersion)" }
            let exe = (info?["CFBundleExecutable"] as? String) ?? "GeometryJump"
            inst.encrypted = MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent(exe))

            if inst.encrypted && !Variant.current.canDecrypt {
                throw StoreError.message("That IPA is still FairPlay-encrypted, so it can't run here. Import a decrypted IPA instead.")
            }
            if !Variant.current.canDecrypt { try? fm.removeItem(at: ipa) } // privileged builds keep it to decrypt later
            store.add(inst)
            pm.wrappedValue.dismiss()
        } catch {
            try? fm.removeItem(at: inst.root)
            self.error = error.localizedDescription
        }
    }

    @MainActor func load() async {
        guard var a = acct.account, versions.isEmpty else { return }
        do { versions = try await AppStoreClient.shared.versions(account: &a); acct.account = a; picked = versions.first }
        catch { self.error = error.localizedDescription }
    }
    @MainActor func create() async {
        guard let a = acct.account, let v = picked else { return }
        progress = 0.1; error = nil
        let inst = Instance(name: name == "Geometry Dash" ? "Geometry Dash \(v.version)" : name, gdVersion: v.version, externalVersionId: v.externalId)
        do {
            let done = try await IPAInstaller.install(version: v, account: a, into: inst) { progress = $0 }
            store.add(done); pm.wrappedValue.dismiss()
        } catch { self.error = error.localizedDescription; progress = nil }
    }
    @MainActor func fromInstalled() async {
        guard let v = Decryptor.installedVersion else { return }
        busy = true; error = nil; defer { busy = false }
        var inst = Instance(name: name == "Geometry Dash" ? "Geometry Dash \(v)" : name, gdVersion: v)
        let target = inst
        do {
            PLog.log("use installed copy: GD \(v)")
            try await Decryptor.inBackground { try Decryptor.decryptInstalled(into: target) }
            try FileManager.default.createDirectory(at: inst.dataDir, withIntermediateDirectories: true)
            inst.encrypted = MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent("GeometryJump"))
            store.add(inst); pm.wrappedValue.dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

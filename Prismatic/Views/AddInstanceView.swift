import SwiftUI

struct AddInstanceView: View {
    @EnvironmentObject var store: InstanceStore
    @EnvironmentObject var acct: AccountState
    @Environment(\.presentationMode) var pm
    @State private var name = "Geometry Dash"
    @State private var versions: [GDVersion] = []
    @State private var picked: GDVersion?
    @State private var progress: Double?, error: String?

    var body: some View {
        NavigationView {
            Form {
                TextField("Instance name", text: $name)
                if Variant.current.canDecrypt {
                    Section(header: Text("From this device"),
                            footer: Text(Decryptor.installedVersion.map { "Installed: GD \($0)" } ?? "Geometry Dash isn't installed.")) {
                        Button("Use installed copy (decrypt)") { fromInstalled() }.disabled(Decryptor.installedVersion == nil)
                    }
                }
                Section(header: Text("Pull from App Store")) {
                    if acct.account == nil { Text("Sign in with your Apple ID first.").foregroundColor(.secondary) }
                    else if versions.isEmpty && error == nil { ProgressView() }
                    ForEach(versions) { v in
                        Button { picked = v } label: {
                            HStack { Text(v.version); Spacer(); if picked == v { Image(systemName: "checkmark") } }
                        }.foregroundColor(.primary)
                    }
                }
                if let progress = progress { ProgressView(value: progress) }
                if let error = error { Text(error).foregroundColor(.red) }
            }
            .navigationTitle("New instance")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await create() } }.disabled(picked == nil || progress != nil) } }
            .onAppear { Task { await load() } }
        }
    }
    @MainActor func load() async {
        guard let a = acct.account, versions.isEmpty else { return }
        do { versions = try await AppStoreClient().versions(account: a); picked = versions.first }
        catch { self.error = error.localizedDescription }
    }
    @MainActor func create() async {
        guard let a = acct.account, let v = picked else { return }
        progress = 0.1
        let inst = Instance(name: name, gdVersion: v.version, externalVersionId: v.externalId)
        do {
            let done = try await IPAInstaller.install(version: v, account: a, into: inst) { progress = $0 }
            store.add(done); pm.wrappedValue.dismiss()
        } catch { self.error = error.localizedDescription; progress = nil }
    }
    @MainActor func fromInstalled() {
        guard let v = Decryptor.installedVersion else { return }
        var inst = Instance(name: name, gdVersion: v)
        do {
            try Decryptor.decryptInstalled(into: inst)
            try FileManager.default.createDirectory(at: inst.dataDir, withIntermediateDirectories: true)
            inst.encrypted = MachOInspector.isEncrypted(inst.appBundle.appendingPathComponent("GeometryJump"))
            store.add(inst); pm.wrappedValue.dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

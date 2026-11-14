import SwiftUI

struct AddInstanceView: View {
    @EnvironmentObject var store: InstanceStore
    @EnvironmentObject var acct: AccountState
    @Environment(\.dismiss) var dismiss
    @State private var name = "Geometry Dash"
    @State private var versions: [GDVersion] = []
    @State private var picked: GDVersion?
    @State private var progress: Double?, error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Instance name", text: $name)
                Section("Version") {
                    if versions.isEmpty { ProgressView("Loading versions from App Store…") }
                    ForEach(versions) { v in
                        Button { picked = v } label: {
                            HStack { Text(v.version); Spacer(); if picked == v { Image(systemName: "checkmark") } }
                        }.foregroundStyle(.primary)
                    }
                }
                if let progress { ProgressView(value: progress) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("New instance")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await create() } }.disabled(picked == nil || progress != nil) } }
            .task { await load() }
        }
    }
    func load() async {
        guard let a = acct.account else { return }
        do { versions = try await AppStoreClient().versions(account: a); picked = versions.first }
        catch { self.error = error.localizedDescription }
    }
    func create() async {
        guard let a = acct.account, let v = picked else { return }
        progress = 0.1
        let inst = Instance(name: name, gdVersion: v.version, externalVersionId: v.externalId)
        do {
            let done = try await IPAInstaller.install(version: v, account: a, into: inst) { progress = $0 }
            store.add(done); dismiss()
        } catch { self.error = error.localizedDescription; progress = nil }
    }
}

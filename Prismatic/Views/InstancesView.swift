import SwiftUI

struct InstancesView: View {
    @EnvironmentObject var store: InstanceStore
    @EnvironmentObject var acct: AccountState
    @State private var adding = false, signingIn = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.instances) { inst in
                    NavigationLink(value: inst) { row(inst) }
                }.onDelete { $0.map { store.instances[$0] }.forEach(store.delete) }
                if store.instances.isEmpty {
                    ContentUnavailableView("No instances", systemImage: "square.stack.3d.up",
                        description: Text("Tap + to pull a Geometry Dash version from the App Store."))
                }
            }
            .navigationTitle("Prismatic")
            .navigationDestination(for: Instance.self) { InstanceDetailView(instance: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(acct.account == nil ? "Sign in" : acct.account!.email) { signingIn = true }.font(.footnote)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { acct.account == nil ? (signingIn = true) : (adding = true) } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { AddInstanceView() }
            .sheet(isPresented: $signingIn) { SignInView() }
            .alert("Error", isPresented: .constant(error != nil)) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }

    func row(_ i: Instance) -> some View {
        HStack {
            Image(systemName: "diamond.fill").foregroundStyle(.purple.gradient).font(.title2)
            VStack(alignment: .leading) {
                Text(i.name).font(.headline)
                Text("GD \(i.gdVersion)" + (i.geodeVersion.map { " · Geode \($0)" } ?? "")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

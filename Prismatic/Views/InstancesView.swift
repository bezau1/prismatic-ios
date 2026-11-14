import SwiftUI

struct InstancesView: View {
    @EnvironmentObject var store: InstanceStore
    @EnvironmentObject var acct: AccountState
    @State private var adding = false, signingIn = false

    var body: some View {
        NavigationView {
            List {
                ForEach(store.instances) { inst in
                    NavigationLink(destination: InstanceDetailView(instance: inst)) { row(inst) }
                }.onDelete { idx in idx.map { store.instances[$0] }.forEach(store.delete) }
                if store.instances.isEmpty {
                    Text("No instances yet. Tap + to add a Geometry Dash version.").foregroundColor(.secondary)
                }
            }
            .navigationTitle("Prismatic")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(acct.account?.email ?? "Sign in") { signingIn = true }.font(.footnote)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { (acct.account == nil && !Variant.current.canDecrypt) ? (signingIn = true) : (adding = true) }
                        label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { AddInstanceView().environmentObject(store).environmentObject(acct) }
            .sheet(isPresented: $signingIn) { SignInView().environmentObject(acct) }
        }.navigationViewStyle(StackNavigationViewStyle())
    }

    func row(_ i: Instance) -> some View {
        HStack {
            Image(systemName: "diamond.fill").foregroundColor(.purple).font(.title2)
            VStack(alignment: .leading) {
                Text(i.name).font(.headline)
                Text("GD \(i.gdVersion)" + (i.geodeVersion.map { " · Geode \($0)" } ?? "") + (i.encrypted ? " · encrypted" : ""))
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

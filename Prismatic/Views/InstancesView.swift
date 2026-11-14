import SwiftUI

struct InstancesView: View {
    @EnvironmentObject var store: InstanceStore
    @EnvironmentObject var acct: AccountState
    @State private var adding = false
    @State private var showLogs = false
    @State private var launchError: String?
    @State private var exportItem: ExportItem?
    @State private var exportError: String?

    var body: some View {
        NavigationView {
            List {
                ForEach(store.instances) { inst in
                    NavigationLink(destination: InstanceDetailView(instance: inst)) { row(inst) }
                        .contextMenu {
                            if !inst.encrypted {
                                Button { export(inst) } label: { Label("Export decrypted IPA", systemImage: "square.and.arrow.up") }
                            }
                            Button { store.delete(inst) } label: { Label("Delete", systemImage: "trash") }
                        }
                }.onDelete { idx in idx.map { store.instances[$0] }.forEach(store.delete) }
                if let e = launchError { Text(e).foregroundColor(.red) }
                if let e = exportError { Text(e).foregroundColor(.red) }
                if store.instances.isEmpty {
                    Text("No instances yet. Tap + and import a Geometry Dash IPA.").foregroundColor(.secondary)
                }
            }
            .navigationTitle("Prismatic")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Logs") { showLogs = true }.font(.footnote)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { AddInstanceView().environmentObject(store).environmentObject(acct) }
            .sheet(isPresented: $showLogs) { LogView() }
            .onAppear { launchError = LaunchStatus.take() }
            .sheet(item: $exportItem) { ShareSheet(url: $0.url) }
        }.navigationViewStyle(StackNavigationViewStyle())
    }

    func export(_ inst: Instance) {
        exportError = nil
        Task {
            do { exportItem = ExportItem(url: try await Task.detached { try IPAExporter.export(inst) }.value) }
            catch { exportError = error.localizedDescription }
        }
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

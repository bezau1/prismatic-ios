import SwiftUI

struct GeodeSheet: View {
    let instance: Instance
    @Environment(\.presentationMode) var pm
    @State private var ipa: URL?
    @State private var error: String?
    @State private var share: ExportItem?
    @State private var installed = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("1. Geode launcher"),
                        footer: Text(instance.gdVersion == GeodeHandoff.newestLauncherGD
                                     ? "The newest Geode launcher is built for this version."
                                     : "Your game is \(instance.gdVersion). The newest launcher expects \(GeodeHandoff.newestLauncherGD); for older versions use the launcher release made for that version.")) {
                    Text(installed ? "Geode launcher found on this device" : "Geode launcher not found")
                        .foregroundColor(installed ? .green : .secondary)
                    Button("Get the Geode launcher") { UIApplication.shared.open(GeodeHandoff.releasesURL) }
                }
                Section(header: Text("2. Your decrypted game"),
                        footer: Text("A clean copy of this instance's decrypted IPA, ready for the launcher to patch.")) {
                    if let ipa = ipa {
                        Text("Prismatic ▸ Exports ▸ \(ipa.lastPathComponent)").font(.footnote)
                        Button("Show in Files") { GeodeHandoff.openFiles(at: ipa.deletingLastPathComponent()) }
                        Button("Share…") { share = ExportItem(url: ipa) }
                    } else if let error = error {
                        Text(error).foregroundColor(.red)
                    } else { ProgressView("Preparing…") }
                }
                Section(header: Text("3. Patch it with Geode"),
                        footer: Text("In the Geode launcher tap Import IPA and choose the file above. The launcher then patches and runs it itself.")) {
                    Button("Open Geode launcher") { GeodeHandoff.openLauncher() }.disabled(!installed)
                }
            }
            .navigationTitle("Geode mode")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { pm.wrappedValue.dismiss() } } }
            .sheet(item: $share) { ShareSheet(url: $0.url) }
            .onAppear {
                installed = GeodeHandoff.launcherInstalled
                Task {
                    do { ipa = try await Task.detached { try GeodeHandoff.prepare(instance) }.value }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }
}

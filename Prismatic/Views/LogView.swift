import SwiftUI

struct LogView: View {
    @Environment(\.presentationMode) var pm
    @State private var text = PLog.read()
    @State private var share: ExportItem?

    var body: some View {
        NavigationView {
            ScrollView {
                Text(text.isEmpty ? "(empty)" : text)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { pm.wrappedValue.dismiss() } }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Refresh") { text = PLog.read() }
                    Button("Share") { share = ExportItem(url: URL(fileURLWithPath: PLog.path)) }
                    Button("Clear") { PLog.clear(); text = PLog.read() }
                }
            }
            .sheet(item: $share) { ShareSheet(url: $0.url) }
        }
    }
}

import SwiftUI
import ApplePackage

struct PrismaticApp: App {
    @StateObject private var store = InstanceStore()
    @StateObject private var account = AccountState()
    var body: some Scene {
        WindowGroup {
            InstancesView().environmentObject(store).environmentObject(account)
                .accentColor(.purple)
        }
    }
}

final class AccountState: ObservableObject {
    @Published var account: AppStoreAccount? {
        didSet {
            if let a = account, let d = try? JSONEncoder().encode(a) { Keychain.save(d, key: "account") }
            else if account == nil { Keychain.delete(key: "account") }
        }
    }
    init() {
        if let d = Keychain.load(key: "account") { account = try? JSONDecoder().decode(AppStoreAccount.self, from: d) }
    }
}

import SwiftUI

@main
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
        didSet { if let a = account, let d = try? JSONEncoder().encode(a) {
            UserDefaults.standard.set(d, forKey: "account") }
            else if account == nil { UserDefaults.standard.removeObject(forKey: "account") } }
    }
    init() { // TODO: move to Keychain before shipping
        if let d = UserDefaults.standard.data(forKey: "account") {
            account = try? JSONDecoder().decode(AppStoreAccount.self, from: d) }
    }
}

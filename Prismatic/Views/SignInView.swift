import SwiftUI

struct SignInView: View {
    @EnvironmentObject var acct: AccountState
    @Environment(\.presentationMode) var pm
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var needs2FA = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text("Use the Apple ID that purchased Geometry Dash. Credentials go straight to Apple; only a session token is stored.")) {
                    TextField("Apple ID", text: $email).autocapitalization(.none).keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                    if needs2FA { TextField("2FA code", text: $code).keyboardType(.numberPad) }
                }
                if let error = error { Text(error).foregroundColor(.red) }
                Button(busy ? "Signing in…" : "Sign in") { Task { await go() } }.disabled(busy || email.isEmpty)
                if acct.account != nil { Button("Sign out") { acct.account = nil; pm.wrappedValue.dismiss() }.foregroundColor(.red) }
            }.navigationTitle("App Store")
        }
    }
    @MainActor func go() async {
        busy = true; defer { busy = false }
        do {
            acct.account = try await AppStoreClient().login(email: email, password: password, code: needs2FA ? code : nil)
            pm.wrappedValue.dismiss()
        } catch StoreError.twoFactorRequired { needs2FA = true; error = "Enter the code Apple just sent, then tap Sign in again." }
        catch { self.error = error.localizedDescription }
    }
}
